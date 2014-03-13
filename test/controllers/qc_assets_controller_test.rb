require 'test_helper'

class QcAssetsControllerTest < ActionController::TestCase

  include MockApi

  setup do
    mock_api
    api.mock_user('abcdef','11111111-2222-3333-4444-555555555555')
  end

  test "new qc" do
    get :new
    assert_response :success
  end

  test "search" do
    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
    expects(:first).
    with(:barcode => '122000000867').
    returns(api.asset.with_uuid('11111111-2222-3333-4444-300000000008'))

    api.asset.with_uuid('11111111-2222-3333-4444-300000000008').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end

    @request.headers["Accept"] = "application/json"
    get :search, {:user_swipecard=>'abcdef',:asset_barcode=>'122000000867'}

    assert_response :success
    present = assigns['presenter']
    assert_equal '11111111-2222-3333-4444-300000000008', present.uuid
    assert_equal 'Tag Plate', present.purpose
    assert_equal({'Tag PCR'=>'53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc'}, present.child_purposes)
    assert_equal [], present.children
    assert_equal 'pending', present.state
  end

  test "search with children" do
    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
    expects(:first).
    with(:barcode => '122000000867').
    returns(api.asset.with_uuid('11111111-2222-3333-4444-400000000008'))

    api.asset.with_uuid('11111111-2222-3333-4444-400000000008').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end

    @request.headers["Accept"] = "application/json"
    get :search, {:user_swipecard=>'abcdef',:asset_barcode=>'122000000867'}

    assert_response :success
    present = assigns['presenter']
    assert_equal '11111111-2222-3333-4444-400000000008', present.uuid
    assert_equal 'Tag Plate', present.purpose
    assert_equal({'Tag PCR'=>'53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc'}, present.child_purposes)
    assert_equal 1, present.children.size
    assert_equal '11111111-2222-3333-4444-500000000008', present.children.first.uuid
    assert_equal 'passed', present.state
  end

  test "search for tube" do
    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
    expects(:first).
    with(:barcode => '3980000037732').
    returns(api.asset.with_uuid('11111111-2222-3333-4444-600000000008'))

    api.asset.with_uuid('11111111-2222-3333-4444-600000000008').class_eval do
      include Gatekeeper::Tube::ModelExtensions
    end

    @request.headers["Accept"] = "application/json"
    get :search, {:user_swipecard=>'abcdef',:asset_barcode=>'3980000037732'}

    assert_response :success
    present = assigns['presenter']
    assert_equal '11111111-2222-3333-4444-600000000008', present.uuid
    assert_equal 'Tag Stock-MX', present.purpose
    assert_equal({'Tag MX'=>'541b5170-a3c8-11e3-a7e1-44fb42fffecc'}, present.child_purposes)
    assert_equal 1, present.children.size
    assert_equal '11111111-2222-3333-4444-700000000008', present.children.first.uuid
    assert_equal 'pending', present.state
  end

  test "create standard" do

    api.asset.with_uuid('11111111-2222-3333-4444-500000000008').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end
    api.plate_creation.with_uuid('11111111-2222-3333-4444-330000000008').child.class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end


    api.plate_creation.expect_create_with(
      :received => {
          :parent => '11111111-2222-3333-4444-500000000008',
          :child_purpose => '54088cc0-a3c8-11e3-a7e1-44fb42fffecc',
          :user => '11111111-2222-3333-4444-555555555555'
        },
      :returns => '11111111-2222-3333-4444-330000000008'
      )
    api.transfer_template.with_uuid('8c716230-a922-11e3-926d-44fb42fffecc').expects(:create!).with(
        :source      => '11111111-2222-3333-4444-500000000008',
        :destination => '11111111-2222-3333-4444-510000000008',
        :user        => '11111111-2222-3333-4444-555555555555'
    )

    @request.headers["Accept"] = "application/json"
    post :create, {
      :user_swipecard=>'abcdef',
      :parent=>'11111111-2222-3333-4444-500000000008',
      :purpose=>'54088cc0-a3c8-11e3-a7e1-44fb42fffecc'
    }
    assert_equal nil, flash[:danger]
    assert_response :created

    present = assigns['presenter']
    assert_equal '11111111-2222-3333-4444-510000000008', present.uuid
    assert_equal 'Tag PCR-XP', present.purpose
    assert_equal({'Tag Stock-MX'=>'5412ed00-a3c8-11e3-a7e1-44fb42fffecc'}, present.child_purposes)
  end

  test "create convert tag" do

    api.asset.with_uuid('11111111-2222-3333-4444-300000000008').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end
    api.asset.with_uuid('11111111-2222-3333-4444-100000000011').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end
    api.plate_conversion.with_uuid('11111111-2222-3333-4444-340000000008').target.class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end

    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
      expects(:first).
      with(:barcode => '122000001174').
      returns(api.plate.with_uuid('11111111-2222-3333-4444-100000000011'))


    api.plate_conversion.expect_create_with(
      :received => {
          :target => '11111111-2222-3333-4444-300000000008',
          :purpose => '53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc',
          :user => '11111111-2222-3333-4444-555555555555'
        },
      :returns => '11111111-2222-3333-4444-340000000008'
      )
      api.transfer_template.with_uuid('8c716230-a922-11e3-926d-44fb42fffecc').expects(:create!).with(
        :source      => '11111111-2222-3333-4444-100000000011',
        :destination => '11111111-2222-3333-4444-300000000008',
        :user        => '11111111-2222-3333-4444-555555555555'
      )

    @request.headers["Accept"] = "application/json"
    post :create, {
      :user_swipecard =>'abcdef',
      :parent         =>'11111111-2222-3333-4444-300000000008',
      :purpose        =>'53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc',
      :sibling        => '122000001174'
    }
    assert_equal nil, flash[:danger]
    assert_response :created

    present = assigns['presenter']
    assert_equal '11111111-2222-3333-4444-500000000008', present.uuid
    assert_equal 'Tag PCR', present.purpose
    assert_equal({'Tag PCR-XP'=>'54088cc0-a3c8-11e3-a7e1-44fb42fffecc'}, present.child_purposes)
  end

  test "create convert reporter" do

    api.asset.with_uuid('11111111-2222-3333-4444-300000000008').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
      def state; 'available'; end
    end
    api.asset.with_uuid('11111111-2222-3333-4444-100000000011').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
      def state; 'pending'; end
    end
    api.plate_conversion.with_uuid('11111111-2222-3333-4444-340000000008').target.class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end

    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
      expects(:first).
      with(:barcode => '122000000867').
      returns(api.plate.with_uuid('11111111-2222-3333-4444-300000000008'))


    api.plate_conversion.expect_create_with(
      :received => {
          :target => '11111111-2222-3333-4444-300000000008',
          :purpose => '53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc',
          :user => '11111111-2222-3333-4444-555555555555'
        },
      :returns => '11111111-2222-3333-4444-340000000008'
      )
    api.transfer_template.with_uuid('8c716230-a922-11e3-926d-44fb42fffecc').expects(:create!).with(
      :source      => '11111111-2222-3333-4444-100000000011',
      :destination => '11111111-2222-3333-4444-300000000008',
      :user        => '11111111-2222-3333-4444-555555555555'
    )

    @request.headers["Accept"] = "application/json"
    post :create, {
      :user_swipecard =>'abcdef',
      :parent         =>'11111111-2222-3333-4444-100000000011',
      :purpose        =>'53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc',
      :sibling        => '122000000867'
    }
    assert_equal nil, flash[:danger]
    assert_response :created

    present = assigns['presenter']
    assert_equal '11111111-2222-3333-4444-500000000008', present.uuid
    assert_equal 'Tag PCR', present.purpose
    assert_equal({'Tag PCR-XP'=>'54088cc0-a3c8-11e3-a7e1-44fb42fffecc'}, present.child_purposes)
  end

  test "smart state detection" do

    reporter_plate = '11111111-2222-3333-4444-100000000011'
    tag_plate      = '11111111-2222-3333-4444-300000000008'

    api.asset.with_uuid('11111111-2222-3333-4444-300000000008').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end
    api.asset.with_uuid('11111111-2222-3333-4444-100000000011').class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end
    api.plate_conversion.with_uuid('11111111-2222-3333-4444-340000000008').target.class_eval do
      include Gatekeeper::Plate::ModelExtensions
      include StateExtensions
    end

    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
      stubs(:first).
      with(:barcode => '122000000867').
      returns(api.plate.with_uuid('11111111-2222-3333-4444-300000000008'))
    api.search.with_uuid('e7d2fec0-956f-11e3-8255-44fb42fffecc').
      stubs(:first).
      with(:barcode => '122000001174').
      returns(api.plate.with_uuid('11111111-2222-3333-4444-100000000011'))

    [
      {
        :protagonist => tag_plate,
        :sibling => reporter_plate,
        :sibling_bc => '122000001174',
        :protagonist_state => 'pending',
        :sibling_state => 'available',
        :success => true,
      },
      {
        :protagonist => reporter_plate,
        :sibling => tag_plate,
        :sibling_bc => '122000000867',
        :protagonist_state => 'pending',
        :sibling_state => 'available',
        :success => true
      },
      {
        :protagonist => tag_plate,
        :sibling => reporter_plate,
        :sibling_bc => '122000001174',
        :protagonist_state => 'pending',
        :sibling_state => 'pending',
        :success => false
      },
      {
        :protagonist => tag_plate,
        :sibling => reporter_plate,
        :sibling_bc => '122000001174',
        :protagonist_state => 'available',
        :sibling_state => 'available',
        :success => false
      },
    ].each do |test|

      pc = mock('plate_conversion')
      pc.stubs(:target).returns(api.plate.with_uuid(tag_plate))

      api.plate_conversion.stubs(:create!).returns(pc)

      api.transfer_template.with_uuid('8c716230-a922-11e3-926d-44fb42fffecc').stubs(:create!)

      api.plate.with_uuid(test[:protagonist]).stubs(:state).returns(test[:protagonist_state])
      api.plate.with_uuid(test[:sibling]).stubs(:state).returns(test[:sibling_state])

      @request.headers["Accept"] = "application/json"
      post :create, {
        :user_swipecard=>'abcdef',
        :parent=>test[:protagonist],
        :purpose=>'53e6d3f0-a3c8-11e3-a7e1-44fb42fffecc',
        :sibling => test[:sibling_bc]
      }
      presenter = assigns['presenter']
      returned = test[:success] ? 'Presenter::QcAsset' : 'Presenter::Error'
      assert_equal returned, presenter.class.to_s
    end

  end

end
