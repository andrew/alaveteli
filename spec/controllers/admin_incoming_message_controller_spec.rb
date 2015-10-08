# -*- encoding : utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe AdminIncomingMessageController, "when administering incoming messages" do

  describe 'when destroying an incoming message' do

    before(:each) do
      basic_auth_login @request
      load_raw_emails_data
    end

    before do
      @im = incoming_messages(:useless_incoming_message)
      allow(@controller).to receive(:expire_for_request)
    end

    it "destroys the raw email file" do
      raw_email = @im.raw_email.filepath
      assert_equal File.exists?(raw_email), true
      post :destroy, :id => @im.id
      assert_equal File.exists?(raw_email), false
    end

    it 'asks the incoming message to destroy itself' do
      allow(IncomingMessage).to receive(:find).and_return(@im)
      expect(@im).to receive(:destroy)
      post :destroy, :id => @im.id
    end

    it 'expires the file cache for the associated info_request' do
      expect(@controller).to receive(:expire_for_request).with(@im.info_request)
      post :destroy, :id => @im.id
    end

  end

  describe 'when redelivering an incoming message' do

    before(:each) do
      basic_auth_login @request
      load_raw_emails_data
    end

    it 'expires the file cache for the previous request' do
      current_info_request = info_requests(:fancy_dog_request)
      destination_info_request = info_requests(:naughty_chicken_request)
      incoming_message = incoming_messages(:useless_incoming_message)
      expect(@controller).to receive(:expire_for_request).with(current_info_request)
      post :redeliver, :id => incoming_message.id,
        :url_title => destination_info_request.url_title
    end

    it 'should succeed, even if a duplicate xapian indexing job is created' do

      with_duplicate_xapian_job_creation do
        current_info_request = info_requests(:fancy_dog_request)
        destination_info_request = info_requests(:naughty_chicken_request)
        incoming_message = incoming_messages(:useless_incoming_message)
        post :redeliver, :id => incoming_message.id,
          :url_title => destination_info_request.url_title
      end

    end

    it 'shouldn\'t do anything if no message_id is supplied' do
      incoming_message = FactoryGirl.create(:incoming_message)
      post :redeliver, :id => incoming_message.id,
        :url_title => ''
      # It shouldn't delete this message
      assert_equal IncomingMessage.exists?(incoming_message.id), true
      # Should show an error to the user
      assert_equal flash[:error], "You must supply at least one request to redeliver the message to."
      expect(response).to redirect_to admin_request_url(incoming_message.info_request)
    end


  end

  describe 'when editing an incoming message' do

    before do
      @incoming = FactoryGirl.create(:incoming_message)
    end

    it 'should be successful' do
      get :edit, :id => @incoming.id
      expect(response).to be_success
    end

    it 'should assign the incoming message to the view' do
      get :edit, :id => @incoming.id
      expect(assigns[:incoming_message]).to eq(@incoming)
    end

  end

  describe 'when updating an incoming message' do

    before do
      @incoming = FactoryGirl.create(:incoming_message, :prominence => 'normal')
      @default_params = {:id => @incoming.id,
                         :incoming_message => {:prominence => 'hidden',
                                               :prominence_reason => 'dull'} }
    end

    def make_request(params=@default_params)
      post :update, params
    end

    it 'should save the prominence of the message' do
      make_request
      @incoming.reload
      expect(@incoming.prominence).to eq('hidden')
    end

    it 'should save a prominence reason for the message' do
      make_request
      @incoming.reload
      expect(@incoming.prominence_reason).to eq('dull')
    end

    it 'should log an "edit_incoming" event on the info_request' do
      allow(@controller).to receive(:admin_current_user).and_return("Admin user")
      make_request
      @incoming.reload
      last_event = @incoming.info_request_events.last
      expect(last_event.event_type).to eq('edit_incoming')
      expect(last_event.params).to eq({ :incoming_message_id => @incoming.id,
                                    :editor => "Admin user",
                                    :old_prominence => "normal",
                                    :prominence => "hidden",
                                    :old_prominence_reason => nil,
                                    :prominence_reason => "dull" })
    end

    it 'should expire the file cache for the info request' do
      expect(@controller).to receive(:expire_for_request).with(@incoming.info_request)
      make_request
    end

    context 'if the incoming message saves correctly' do

      it 'should redirect to the admin info request view' do
        make_request
        expect(response).to redirect_to admin_request_url(@incoming.info_request)
      end

      it 'should show a message that the incoming message has been updated' do
        make_request
        expect(flash[:notice]).to eq('Incoming message successfully updated.')
      end

    end

    context 'if the incoming message is not valid' do

      it 'should render the edit template' do
        make_request({:id => @incoming.id,
                      :incoming_message => {:prominence => 'fantastic',
                                            :prominence_reason => 'dull'}})
        expect(response).to render_template("edit")
      end

    end
  end

end
