# -*- coding: utf-8 -*-
require 'spec_helper'

describe MongoidCacheStore do
  describe "#new" do
    context "when omit collection_name" do
      before { MongoidCacheStore.new }
      it "should be 'rails_cache_store'" do
        MongoidCacheStore::CacheStore.collection_name.to_s.should eql('rails_cache_store')
      end
    end

    context "when omit database_name" do
      before { MongoidCacheStore.new }
      it "should be setting value in mongoid.yml" do
        MongoidCacheStore::CacheStore.database_name.to_s.should eql('mongoid_cache_store_test')
      end
    end

    context "with collection_name" do
      before { MongoidCacheStore.new(collection_name: 'cache_store_collection') }
      it "should be specified collection" do
        MongoidCacheStore::CacheStore.collection_name.to_s.should eql('cache_store_collection')
      end
    end

    context "with database_name" do
      before { MongoidCacheStore.new(database_name: 'cache_store_db') }
      it "should be specified database" do
        MongoidCacheStore::CacheStore.database_name.to_s.should eql('cache_store_db')
      end
    end
  end

  describe "#pack/#unpack" do
    let!(:store) { MongoidCacheStore.new }
    [nil,"STRING",:SYMBOL,100,0.05,Time.now,{},{a:1,b:1},[],[:a,:b],{a:[1,2,{x:'x',y:'y'},3]}].each do |value|
      it "shuld be able to restore #{value.inspect}" do
        store.__send__(:unpack, store.__send__(:pack, value)).should eql(value)
      end
    end
  end

  context "override ActiveSupport::Cache::Store" do
    let!(:store) { MongoidCacheStore.new }
    let(:base_time) { Time.parse('2012-01-01 13:00:00') }
    def create_data
      5.times do |n|
        MongoidCacheStore::CacheStore.create(_id: "key_#{n}", expires: base_time + n.hour)
      end
    end
    context "when all cache is expiration" do
      before do
        create_data
        Time.should_receive(:now).any_number_of_times.and_return(base_time + 5.hour)
      end
      describe "#cleanup" do
        before { store.cleanup }
        it "should all data is delete" do
          MongoidCacheStore::CacheStore.all.count.should == 0
        end
      end

      describe "#clear" do
        before { store.clear }
        it "should all data is delete" do
          MongoidCacheStore::CacheStore.all.count.should == 0
        end
      end

      describe "#read_entry" do
        let(:key_0) { store.__send__(:read_entry, "key_0") }
        it "should not read" do
          key_0.should be_nil
        end
      end

      describe "#delete_entry" do
        let!(:key_0) { store.__send__(:delete_entry, "key_0") }
        it "should return true" do
          key_0.should be_true
        end
        it "should be deleted" do
          MongoidCacheStore::CacheStore.where(_id: "key_0").first.should be_nil
        end
      end
    end

    context "when several data is expiration" do
      before do
        create_data
        Time.should_receive(:now).any_number_of_times.and_return(base_time + 2.hour)
      end
      describe "#cleanup" do
        before { store.cleanup }
        it "should delete only expires data" do
          MongoidCacheStore::CacheStore.all.count.should == 3
        end
      end

      describe "#clear" do
        before { store.clear }
        it "should all data is delete" do
          MongoidCacheStore::CacheStore.all.count.should == 0
        end
      end

      describe "#read_entry" do
        context "expired data" do
          let(:key_0) { store.__send__(:read_entry, "key_0") }
          it "should not read" do
            key_0.should be_nil
          end
        end
        context "lived data" do
          let(:key_4) { store.__send__(:read_entry, "key_4") }
          it "should read" do
            key_4.should_not be_nil
          end
        end
      end
    end

    context "when no data is expiration" do
      before do
        create_data
        Time.should_receive(:now).any_number_of_times.and_return(base_time)
      end
      describe "#cleanup" do
        before { store.cleanup }
        it "should be remain all data" do
          MongoidCacheStore::CacheStore.all.count.should == 5
        end
      end

      describe "#clear" do
        before { store.clear }
        it "should all data is delete" do
          MongoidCacheStore::CacheStore.all.count.should == 0
        end
      end

      describe "#read_entry" do
        let(:key_2) { store.__send__(:read_entry, "key_2") }
        it "should read" do
          key_2.should_not be_nil
        end
      end

      describe "#delete_entry" do
        let!(:key_2) { store.__send__(:delete_entry, "key_2") }
        it "should return true" do
          key_2.should be_true
        end
        it "should be deleted" do
          MongoidCacheStore::CacheStore.where(_id: "key_2").first.should be_nil
        end
      end

      describe "#delete_matched" do
        before { store.__send__(:delete_matched, %r{key_[0-2]}) }
        it "should be deleted" do
          MongoidCacheStore::CacheStore.where(_id: "key_0").first.should be_nil
          MongoidCacheStore::CacheStore.where(_id: "key_1").first.should be_nil
          MongoidCacheStore::CacheStore.where(_id: "key_2").first.should be_nil
        end
      end
    end

    describe "#write_entry" do
      let(:base_time) { Time.parse('2012-01-01 13:00:00') }
      before { Time.should_receive(:now).any_number_of_times.and_return(base_time) }
      let!(:stored) { store.__send__(:write_entry, "INITIAL KEY", ActiveSupport::Cache::Entry.new("VALUE"), {expires_in: 1.hour}) }
      context "when the key which does not exist yet" do
        it "should return true" do
          stored.should be_true
        end
        it "should be stored" do
          MongoidCacheStore::CacheStore.where(_id: "INITIAL KEY").first.should_not be_nil
        end
      end

      context "when the key which does exist" do
        let!(:second) { store.__send__(:write_entry, "INITIAL KEY", ActiveSupport::Cache::Entry.new("VALUE 2"), {expires_in: 24.hours}) }
        it "should return true" do
          second.should be_true
        end
        it "should be updated at expires" do
          stored = MongoidCacheStore::CacheStore.where(_id: "INITIAL KEY").first
          stored.expires == base_time + 24.hours
        end
      end

      context "when omit expires_in" do
        let!(:second) { store.__send__(:write_entry, "INITIAL KEY", ActiveSupport::Cache::Entry.new("VALUE 2"), {}) }
        it "should return true" do
          second.should be_true
        end
        it "should be updated at default expires" do
          stored = MongoidCacheStore::CacheStore.where(_id: "INITIAL KEY").first
          stored.expires == base_time + ActiveSupport::Cache::MongoidCacheStore::DEFAULT_EXPIRES_IN
        end
      end
    end
  end
end

describe MongoidCacheStore::CacheStore do
  describe "id field" do
    def create
      MongoidCacheStore::CacheStore.create(_id: "KEY_STRING")
    end
    let(:model) { create }
    it "should be able to store as cache key" do
      model.reload.id.should eql("KEY_STRING")
    end
    before do
      model
    end
    it "should be unique field" do
      expect { create }.to raise_error(/duplicate key/)
    end
  end

  describe "expires field" do
    let(:now_time) { Time.parse('2012-01-01 13:00:00') }
    before do
      Time.should_receive(:now).any_number_of_times.and_return(now_time)
    end
    context "MongoidCacheStore#new without expires_in option" do
      let!(:store) { MongoidCacheStore.new }
      it "should set current time + MongoidCacheStore::DEFAULT_EXPIRES_IN as default" do
        c = MongoidCacheStore::CacheStore.create(_id: "KEY_STRING")
        c.reload.expires.should == now_time + MongoidCacheStore::DEFAULT_EXPIRES_IN
      end
    end
    context "MongoidCacheStore#new with expires_in: 1.hour option" do
      let(:expires_in) { 1.hour }
      let!(:store) { MongoidCacheStore.new(expires_in: expires_in) }
      it "should set current time + 1.hour as default" do
        c = MongoidCacheStore::CacheStore.create(_id: "KEY_STRING")
        c.reload.expires.should == now_time + expires_in
      end
    end
    it "should be storeable value" do
      MongoidCacheStore::CacheStore.create(_id: "KEY_STRING", expires: now_time).reload.expires.should == now_time
    end
  end

  describe "data field" do
    context "when data field is not specified" do
      let (:cache_store) { MongoidCacheStore::CacheStore.create(_id: "KEY_STRING") }
      it "empty hash should be stored" do
        Marshal.load(StringIO.new(cache_store.reload.data.to_s)).should eql({})
      end
    end
    it "should be storeable value" do
      c = MongoidCacheStore::CacheStore.create(_id: "KEY_STRING", data: Moped::BSON::Binary.new(:generic,Marshal.dump("STRING_VALUE")))
      Marshal.load(StringIO.new(c.reload.data.to_s)).should eql("STRING_VALUE")
    end
  end
end