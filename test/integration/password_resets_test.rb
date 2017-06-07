require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end

  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:michael)
  end

  test "password resets" do
    get new_password_reset_path
    assert_template 'password_resets/new'
    # 电子邮件地址无效
    post password_resets_path, params: { password_reset: { email: "" } }
    assert_not_empty flash
    assert_template 'password_resets/new'
    # 电子邮箱地址有效
    post password_resets_path, params: { password_reset: { email: @user.email } }
    assert_not_equal @user.reset_digest, @user.reload.reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not_empty flash
    assert_redirected_to root_url

    # 密码重设表单
    user = assigns(:user)
    # 电子邮箱地址错误
    get edit_password_reset_path(user.reset_token, email: "")
    assert_redirected_to root_url
    # 用户未激活
    user.toggle!(:activated)
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_redirected_to root_url
    user.toggle!(:activated)
    # 电子邮件地址正确，令牌错误
    get edit_password_reset_path("wrong token", email: user.email)
    assert_redirected_to root_url
    # 电子邮件地址正确，令牌正确
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select 'input[name=email][type=hidden][value=?]', user.email

    # 密码与密码确认不匹配
    patch password_reset_path(user.reset_token), params: { user: { password: "boobaz", password_confirmation: "barqljk" }, 
                                                           email: user.email }
    assert_select "div#error_explanation"
    # 密码为空值
    patch password_reset_path(user.reset_token), params: { user: { password: "", password_confirmation: "" }, 
                                                           email: user.email }
    assert_select "div#error_explanation"
    # 密码和密码确认有效
    patch password_reset_path(user.reset_token), params: { user: { password: "foobaz", password_confirmation: "foobaz" }, 
                                                           email: user.email }
    assert is_logged_in?
    assert_not_empty flash
    assert_redirected_to user

  end

  test 'expired token' do
    get new_password_reset_path
    post password_resets_path,
         params: { password_reset: { email: @user.email } }

    @user = assigns(:user)
    @user.update_attribute(:reset_sent_at, 3.hours.ago)
    patch password_reset_path(@user.reset_token),
          params: { email: @user.email,
                    user: { password:              "foobar",
                            password_confirmation: "foobar" } }
    assert_response :redirect
    follow_redirect!
    assert_match /Password reset has expired/i, response.body
  end

end
