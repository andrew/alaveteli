# -*- encoding : utf-8 -*-
# == Schema Information
#
# Table name: users
#
#  id                      :integer          not null, primary key
#  email                   :string(255)      not null
#  name                    :string(255)      not null
#  hashed_password         :string(255)      not null
#  salt                    :string(255)      not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  email_confirmed         :boolean          default(FALSE), not null
#  url_name                :text             not null
#  last_daily_track_email  :datetime         default(Sat Jan 01 00:00:00 UTC 2000)
#  admin_level             :string(255)      default("none"), not null
#  ban_text                :text             default(""), not null
#  about_me                :text             default(""), not null
#  locale                  :string(255)
#  email_bounced_at        :datetime
#  email_bounce_message    :text             default(""), not null
#  no_limit                :boolean          default(FALSE), not null
#  receive_email_alerts    :boolean          default(TRUE), not null
#  can_make_batch_requests :boolean          default(FALSE), not null
#  otp_enabled             :boolean          default(FALSE)
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe User, "making up the URL name" do
  before do
    @user = User.new
  end

  it 'should remove spaces, and make lower case' do
    @user.name = 'Some Name'
    expect(@user.url_name).to eq('some_name')
  end

  it 'should not allow a numeric name' do
    @user.name = '1234'
    expect(@user.url_name).to eq('user')
  end
end

describe User, "banning the user" do

  it 'does not change the URL name' do
    user = FactoryGirl.create(:user, :name => 'nasty user 123')
    user.update_attributes(:ban_text => 'You are banned')
    expect(user.url_name).to eq('nasty_user_123')
  end

  it 'appends a message to the name' do
    user = FactoryGirl.build(:user, :name => 'nasty user', :ban_text => 'banned')
    expect(user.name).to eq('nasty user (Account suspended)')
  end

end

describe User, "showing the name" do
  before do
    @user = User.new
    @user.name = 'Some Name '
  end

  it 'should strip whitespace' do
    expect(@user.name).to eq('Some Name')
  end

  describe  'if user has been banned' do

    before do
      @user.ban_text = "Naughty user"
    end

    it 'should show an "Account suspended" suffix' do
      expect(@user.name).to eq('Some Name (Account suspended)')
    end

    it 'should return a string when the user has been banned, not a SafeBuffer' do
      expect(@user.name.class).to eq(String)
    end
  end


end

describe User, " when authenticating" do
  before do
    @empty_user = User.new

    @full_user = User.new
    @full_user.name = "Sensible User"
    @full_user.password = "foolishpassword"
    @full_user.email = "sensible@localhost"
    @full_user.save
  end

  it "should create a hashed password when the password is set" do
    expect(@empty_user.hashed_password).to be_nil
    @empty_user.password = "a test password"
    expect(@empty_user.hashed_password).not_to be_nil
  end

  it "should have errors when given the wrong password" do
    found_user = User.authenticate_from_form({ :email => "sensible@localhost", :password => "iownzyou" })
    expect(found_user.errors.size).to be > 0
  end

  it "should not find the user when given the wrong email" do
    found_user = User.authenticate_from_form( { :email => "soccer@localhost", :password => "foolishpassword" })
    expect(found_user.errors.size).to be > 0
  end

  it "should find the user when given the right email and password" do
    found_user = User.authenticate_from_form( { :email => "sensible@localhost", :password => "foolishpassword" })
    expect(found_user.errors.size).to eq(0)
    expect(found_user).to eq(@full_user)
  end

end

describe User, " when saving" do
  before do
    @user = User.new
  end

  it "should not save without setting some parameters" do
    expect { @user.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "should not save with misformatted email" do
    @user.name = "Mr. Silly"
    @user.password = "insecurepassword"
    @user.email = "mousefooble"
    @user.valid?
    expect(@user.errors[:email].size).to eq(1)
  end

  it "should not allow an email address as a name" do
    @user.name = "silly@example.com"
    @user.email = "silly@example.com"
    @user.password = "insecurepassword"
    @user.valid?
    expect(@user.errors[:name].size).to eq(1)
  end

  it "should not save with no password" do
    @user.name = "Mr. Silly"
    @user.password = ""
    @user.email = "silly@localhost"
    @user.valid?
    expect(@user.errors[:hashed_password].size).to eq(1)
  end

  it "should save with reasonable name, password and email" do
    @user.name = "Mr. Reasonable"
    @user.password = "insecurepassword"
    @user.email = "reasonable@localhost"
    @user.save!
  end

  it "should let you make two users with same name" do
    @user.name = "Mr. Flobble"
    @user.password = "insecurepassword"
    @user.email = "flobble@localhost"
    @user.save!

    @user2 = User.new
    @user2.name = "Mr. Flobble"
    @user2.password = "insecurepassword"
    @user2.email = "flobble2@localhost"
    @user2.save!
  end

  it "should not let you make two users with same email" do
    @user.name = "Mr. Flobble"
    @user.password = "insecurepassword"
    @user.email = "flobble@localhost"
    @user.save!

    @user2 = User.new
    @user2.name = "Flobble Jr."
    @user2.password = "insecurepassword"
    @user2.email = "flobble@localhost"
    @user2.valid?
    expect(@user2.errors[:email].size).to eq(1)
    expect(@user2.errors[:email][0]).to eq('This email is already in use')

    # should ignore case differences
    @user2.email = "FloBBle@localhost"
    @user2.valid?
    expect(@user2.errors[:email].size).to eq(1)
    expect(@user2.errors[:email][0]).to eq('This email is already in use')
  end

  it 'should mark the model for reindexing in xapian if the no_xapian_reindex flag is set to false' do
    @user.name = "Mr. First"
    @user.password = "insecurepassword"
    @user.email = "reasonable@localhost"
    @user.no_xapian_reindex = false
    expect(@user).to receive(:xapian_mark_needs_index)
    @user.save!
  end

  it 'should mark the model for reindexing in xapian if the no_xapian_reindex flag is not set'  do
    @user.name = "Mr. Second"
    @user.password = "insecurepassword"
    @user.email = "reasonable@localhost"
    @user.no_xapian_reindex = nil
    expect(@user).to receive(:xapian_mark_needs_index)
    @user.save!
  end

  it 'should not mark the model for reindexing in xapian if the no_xapian_reindex flag is set' do
    @user.name = "Mr. Third"
    @user.password = "insecurepassword"
    @user.email = "reasonable@localhost"
    @user.no_xapian_reindex = true
    expect(@user).not_to receive(:xapian_mark_needs_index)
    @user.save!
  end

end


describe User, "when reindexing referencing models" do

  before do
    @request_event = mock_model(InfoRequestEvent, :xapian_mark_needs_index => true)
    @request = mock_model(InfoRequest, :info_request_events => [@request_event])
    @comment_event = mock_model(InfoRequestEvent, :xapian_mark_needs_index => true)
    @comment = mock_model(Comment, :info_request_events => [@comment_event])
    @user = User.new(:comments => [@comment], :info_requests => [@request])
  end

  it 'should reindex events associated with that user\'s comments when URL changes' do
    allow(@user).to receive(:changes).and_return({'url_name' => 1})
    expect(@comment_event).to receive(:xapian_mark_needs_index)
    @user.reindex_referencing_models
  end

  it 'should reindex events associated with that user\'s requests when URL changes' do
    allow(@user).to receive(:changes).and_return({'url_name' => 1})
    expect(@request_event).to receive(:xapian_mark_needs_index)
    @user.reindex_referencing_models
  end

  describe 'when no_xapian_reindex is set' do
    before do
      @user.no_xapian_reindex = true
    end

    it 'should not reindex events associated with that user\'s comments when URL changes' do
      allow(@user).to receive(:changes).and_return({'url_name' => 1})
      expect(@comment_event).not_to receive(:xapian_mark_needs_index)
      @user.reindex_referencing_models
    end

    it 'should not reindex events associated with that user\'s requests when URL changes' do
      allow(@user).to receive(:changes).and_return({'url_name' => 1})
      expect(@request_event).not_to receive(:xapian_mark_needs_index)
      @user.reindex_referencing_models
    end

  end

end

describe User, "when checking abilities" do

  before do
    @user = users(:bob_smith_user)
  end

  it "should not get admin links" do
    expect(@user.admin_page_links?).to be false
  end

  it "should be able to file requests" do
    expect(@user.can_file_requests?).to be true
  end

end

describe User, 'when asked if a user owns every request' do

  before do
    @mock_user = mock_model(User)
  end

  it 'should return false if no user is passed' do
    expect(User.owns_every_request?(nil)).to be false
  end

  it 'should return true if the user has "requires admin" power' do
    allow(@mock_user).to receive(:owns_every_request?).and_return true
    expect(User.owns_every_request?(@mock_user)).to be true
  end

  it 'should return false if the user does not have "requires admin" power' do
    allow(@mock_user).to receive(:owns_every_request?).and_return false
    expect(User.owns_every_request?(@mock_user)).to be false
  end

end

describe User, " when making name and email address" do
  it "should generate a name and email" do
    @user = User.new
    @user.name = "Sensible User"
    @user.email = "sensible@localhost"

    expect(@user.name_and_email).to eq("Sensible User <sensible@localhost>")
  end

  it "should quote name and email with funny characters in the name" do
    @user = User.new
    @user.name = "Silly @ User"
    @user.email = "silly@localhost"

    expect(@user.name_and_email).to eq("\"Silly @ User\" <silly@localhost>")
  end
end

# TODO: not finished
describe User, "when setting a profile photo" do
  before do
    @user = User.new
    @user.name = "Sensible User"
    @user.email = "sensible@localhost"
    @user.password = "sensiblepassword"
  end

  it "should attach it to the user" do
    data = load_file_fixture("parrot.png")
    profile_photo = ProfilePhoto.new(:data => data)
    @user.set_profile_photo(profile_photo)
    expect(profile_photo.user).to eq(@user)
  end

  #    it "should destroy old photos being replaced" do
  #        ProfilePhoto.count.should == 0
  #
  #        data_1 = load_file_fixture("parrot.png")
  #        profile_photo_1 = ProfilePhoto.new(:data => data_1)
  #        data_2 = load_file_fixture("parrot.jpg")
  #        profile_photo_2 = ProfilePhoto.new(:data => data_2)
  #
  #        @user.set_profile_photo(profile_photo_1)
  #        @user.save!
  #        ProfilePhoto.count.should == 1
  #        @user.set_profile_photo(profile_photo_2)
  #        @user.save!
  #        ProfilePhoto.count.should == 1
  #    end
end

describe User, "when unconfirmed" do

  before do
    @user = users(:unconfirmed_user)
  end

  it "should not be emailed" do
    expect(@user.should_be_emailed?).to be false
  end
end

describe User, "when emails have bounced" do

  it "should record bounces" do
    User.record_bounce_for_email("bob@localhost", "The reason we think the email bounced (e.g. a bounce message)")

    user = User.find_user_by_email("bob@localhost")
    expect(user.email_bounced_at).not_to be_nil
    expect(user.email_bounce_message).to eq("The reason we think the email bounced (e.g. a bounce message)")
  end
end

describe User, "when calculating if a user has exceeded the request limit" do

  before do
    @info_request = FactoryGirl.create(:info_request)
    @user = @info_request.user
  end

  it 'should return false if no request limit is set' do
    allow(AlaveteliConfiguration).to receive(:max_requests_per_user_per_day).and_return nil
    expect(@user.exceeded_limit?).to be false
  end

  it 'should return false if the user has not submitted more than the limit' do
    allow(AlaveteliConfiguration).to receive(:max_requests_per_user_per_day).and_return(2)
    expect(@user.exceeded_limit?).to be false
  end

  it 'should return true if the user has submitted more than the limit' do
    allow(AlaveteliConfiguration).to receive(:max_requests_per_user_per_day).and_return(0)
    expect(@user.exceeded_limit?).to be true
  end

  it 'should return false if the user is allowed to make batch requests' do
    @user.can_make_batch_requests = true
    allow(AlaveteliConfiguration).to receive(:max_requests_per_user_per_day).and_return(0)
    expect(@user.exceeded_limit?).to be false
  end


end

describe User do

  describe '#otp_enabled' do

    it 'defaults to false' do
      user = User.new
      expect(user.otp_enabled).to eq(false)
    end

    it 'can be enabled on initialization' do
      user = User.new(:otp_enabled => true)
      expect(user.otp_enabled).to eq(true)
    end

    it 'can be enabled after initialization' do
      user = User.new
      user.otp_enabled = true
      expect(user.otp_enabled).to eq(true)
    end

  end

  describe '#banned?' do

    it 'is banned if the user has ban_text' do
      user = FactoryGirl.build(:user, :ban_text => 'banned')
      expect(user).to be_banned
    end

    it 'is not banned if the user has no ban_text' do
      user = FactoryGirl.build(:user, :ban_text => '')
      expect(user).to_not be_banned
    end

  end

end
