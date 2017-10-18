# frozen_string_literal: true

module Scnnr
  class PollingManager
    MAX_TIMEOUT = 25

    attr_accessor :timeout

    def initialize(timeout)
      case timeout
      when Integer, Float::INFINITY then @timeout = timeout
      else
        raise ArgumentError, "timeout must be Integer or Float::INFINITY, but given: #{timeout}"
      end
    end

    def polling(client, recognition_id, options = {})
      loop do
        timeout = [self.timeout, MAX_TIMEOUT].min
        self.timeout -= timeout
        recognition = client.fetch(recognition_id, options.merge(timeout: timeout, polling: false))
        raise TimeoutError.new('recognition timed out', recognition) if timed_out?(recognition)
        break recognition if recognition.finished? || !remain_timeout?
      end
    end

    private

    def remain_timeout?
      self.timeout.positive?
    end

    def timed_out?(recognition)
      recognition.queued? && !remain_timeout?
    end

    class << self
      def start(client, options, &block)
        timeout = options.delete(:timeout)
        used_timeout = [timeout, MAX_TIMEOUT].min
        recognition = block.call(options.merge(timeout: used_timeout))
        extra_timeout = timeout - used_timeout
        return self.new(extra_timeout).polling(client, recognition.id, options) if recognition.queued? && extra_timeout.positive?
        recognition
      end
    end
  end
end
