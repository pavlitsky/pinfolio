# Page-refresh broadcasts (Post.broadcasts_refreshes) enqueue a Turbo::Streams::BroadcastStreamJob
# per stream; with ImmediateDebouncer (rails_helper) they're enqueued synchronously.
module RefreshBroadcasts
  def refresh_broadcasts_for(streamable)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ streamable ])

    enqueued_jobs.count do |job|
      job["job_class"] == "Turbo::Streams::BroadcastStreamJob" &&
        job["arguments"].first == stream && job["arguments"].last["content"].include?('action="refresh"')
    end
  end
end

RSpec.configure { |config| config.include RefreshBroadcasts }
