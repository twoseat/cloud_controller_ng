module VCAP::CloudController
  class AppLabel < Sequel::Model(:app_labels)
    many_to_one :app,
      class: 'VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true

    def validate
      validates_presence :app_guid
      validates_presence :label_key
      #validates_format /\A([\w\-]+|\*)\z/, :label_key
      #validates_format /\A([\w\-]+|\*)\z/, :label_value if label_value
    end

    def self.select_by(label_selector)
      and_parts = label_selector.scan(/(?:\(.*?\)|[^,])+/)
      dataset = self.evaluate_and_parts(and_parts)
      puts dataset.sql
      dataset.map(&:app_guid)
    end

    def self.evaluate_equal(label_key, label_value)
      self.evaluate_in_set(label_key, label_value)
    end

    def self.evaluate_not_equal(label_key, label_value)
      self.select(:app_guid).except(self.evaluate_equal(label_key, label_value))
    end

    def self.evaluate_in_set(label_key, set)
      self.select(:app_guid).where(label_key: label_key, label_value: split_set(set))
    end

    def self.evaluate_not_in_set(label_key, set)
      self.select(:app_guid).except(self.evaluate_in_set(label_key, set))
    end

    def self.evaluate_existence(label_key, _)
      self.select(:app_guid).where(label_key: label_key)
    end

    def self.evaluate_negated_existence(label_key, _)
      self.select(:app_guid).except(self.evaluate_existence(label_key, _))
    end

    def self.evaluate_and_parts(parts)
      name_re = /\w[-\w\._\/]*\w/
      table = [
        { pattern: /(#{name_re})\s*==?\s*(.*)/, method: :evaluate_equal},
        { pattern: /(#{name_re})\s*!=\s*(.*)/, method: :evaluate_not_equal},
        { pattern: /(#{name_re})\s* in \s*\((.*)\)$/, method: :evaluate_in_set},
        { pattern: /(#{name_re})\s* notin \s*\((.*)\)$/, method: :evaluate_not_in_set},
        { pattern: /^(#{name_re})$/, method: :evaluate_existence},
        { pattern: /^!(#{name_re})$/, method: :evaluate_negated_existence},
      ]
      parts.inject(nil) {| dataset, current_part |
        our_match = nil
        entry = table.find{|t| our_match = t[:pattern].match(current_part)}
        if !entry
          raise StandardError.new("awp you fool")
        end
        ds = self.send(entry[:method], our_match[1], our_match[2])
        if dataset.nil?
          ds
        else
          dataset.intersect(ds)
        end
      }
    end

    private

    def self.split_set(set)
      set.split(',').map { |v| v.strip }
    end
  end
end
