require 'cloud_controller/metrics/statsd_updater'
require 'clockwork'
require 'vcap/stats'

module VCAP::CloudController::Metrics
  class PeriodicUpdater
    def initialize(start_time, log_counter, logger=Steno.logger, updaters=[StatsdUpdater.new])
      @start_time = start_time
      @updaters    = updaters
      @log_counter = log_counter
      @logger = logger
    end

    def setup_updates
      update!
      Clockwork.every(600.seconds, 'record_user_count') { catch_error { record_user_count } }
      Clockwork.every(30.seconds, 'update_job_queue_length')  { catch_error { update_job_queue_length } }
      Clockwork.every(30.seconds, 'update_thread_info')  { catch_error { update_thread_info } }
      Clockwork.every(30.seconds, 'update_failed_job_count')  { catch_error { update_failed_job_count } }
      Clockwork.every(30.seconds, 'update_vitals')  { catch_error { update_vitals } }
      Clockwork.every(30.seconds, 'update_log_counts')  { catch_error { update_log_counts } }
      Clockwork.every(30.seconds, 'update_task_stats')  { catch_error { update_task_stats } }
    end

    def update!
      record_user_count
      update_job_queue_length
      update_thread_info
      update_failed_job_count
      update_vitals
      update_log_counts
      update_task_stats
    end

    def catch_error
      yield
    rescue => e
      @logger.info(e)
    end

    def update_task_stats
      running_tasks = VCAP::CloudController::TaskModel.where(state: VCAP::CloudController::TaskModel::RUNNING_STATE)
      running_task_count = running_tasks.count
      running_task_memory = running_tasks.sum(:memory_in_mb)
      running_task_memory = 0 if running_task_memory.nil?
      @updaters.each { |u| u.update_task_stats(running_task_count, running_task_memory) }
    end

    def update_log_counts
      counts = @log_counter.counts

      hash = {}
      Steno::Logger::LEVELS.each_key do |level_name|
        hash[level_name] = counts.fetch(level_name.to_s, 0)
      end

      @updaters.each { |u| u.update_log_counts(hash) }
    end

    def record_user_count
      user_count = VCAP::CloudController::User.count

      @updaters.each { |u| u.record_user_count(user_count) }
    end

    def update_job_queue_length
      jobs_by_queue_with_count = Delayed::Job.where(attempts: 0).group_and_count(:queue)

      total                      = 0
      pending_job_count_by_queue = jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        total += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      @updaters.each { |u| u.update_job_queue_length(pending_job_count_by_queue, total) }
    end

    def update_thread_info
      local_thread_info = thread_info

      @updaters.each { |u| u.update_thread_info(local_thread_info) }
    end

    def update_failed_job_count
      jobs_by_queue_with_count = Delayed::Job.where(Sequel.lit('failed_at IS NOT NULL')).group_and_count(:queue)

      total                = 0
      failed_jobs_by_queue = jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        total += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      @updaters.each { |u| u.update_failed_job_count(failed_jobs_by_queue, total) }
    end

    def update_vitals
      rss_bytes, pcpu = VCAP::Stats.process_memory_bytes_and_cpu

      vitals = {
        uptime:         Time.now.utc.to_i - @start_time.to_i,
        cpu:            pcpu.to_f,
        mem_bytes:      rss_bytes.to_i,
        cpu_load_avg:   VCAP::Stats.cpu_load_average,
        mem_used_bytes: VCAP::Stats.memory_used_bytes,
        mem_free_bytes: VCAP::Stats.memory_free_bytes,
        num_cores:      VCAP::HostSystem.new.num_cores,
      }

      @updaters.each { |u| u.update_vitals(vitals) }
    end

    def thread_info
      {
        thread_count:  Thread.list.size,
        event_machine: {
          connection_count: 0,
          threadqueue:      {
            size:        0,
            num_waiting: 0,
          },
          resultqueue: {
            size:        0,
            num_waiting: 0,
          },
        },
      }
    end
  end
end
