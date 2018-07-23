# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'

##
# Imports
#
require 'http.pb'
require 'log.pb'
require 'metric.pb'
require 'error.pb'

module Logcache
  module Models
    ##
    # Message Classes
    #
    class Envelope < ::Protobuf::Message
      class EventType < ::Protobuf::Enum
        define :HttpStartStop, 4
        define :LogMessage, 5
        define :ValueMetric, 6
        define :CounterEvent, 7
        define :Error, 8
        define :ContainerMetric, 9
      end

      class TagsEntry < ::Protobuf::Message; end
    end

    ##
    # Message Fields
    #
    class Envelope
      class TagsEntry
        optional :string, :key, 1
        optional :string, :value, 2
      end

      required :string, :origin, 1
      required ::Logcache::Models::Envelope::EventType, :eventType, 2
      optional :int64, :timestamp, 6
      optional :string, :deployment, 13
      optional :string, :job, 14
      optional :string, :index, 15
      optional :string, :ip, 16
      repeated ::Logcache::Models::Envelope::TagsEntry, :tags, 17
      optional ::Logcache::Models::HttpStartStop, :httpStartStop, 7
      optional ::Logcache::Models::LogMessage, :logMessage, 8
      optional ::Logcache::Models::ValueMetric, :valueMetric, 9
      optional ::Logcache::Models::CounterEvent, :counterEvent, 10
      optional ::Logcache::Models::Error, :error, 11
      optional ::Logcache::Models::ContainerMetric, :containerMetric, 12
    end
  end
end
