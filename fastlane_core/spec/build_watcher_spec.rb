require 'spec_helper'

describe FastlaneCore::BuildWatcher do
  context '.wait_for_build_processing_to_be_complete' do
    let(:processing_build) do
      double(
        'Processing Build',
        processed?: false,
        active?: false,
        ready_to_submit?: false,
        export_compliance_missing?: false,
        review_rejected?: false,
        train_version: '1.0',
        build_version: '1',
        upload_date: 1
      )
    end
    let(:old_processing_build) do
      double(
        'Old Processing Build',
        processed?: false,
        active?: false,
        ready_to_submit?: false,
        export_compliance_missing?: false,
        review_rejected?: false,
        train_version: '1.0',
        build_version: '0',
        upload_date: 0
      )
    end
    let(:active_build) do
      double(
        'Active Build',
        processed?: true,
        active?: true,
        ready_to_submit?: false,
        export_compliance_missing?: false,
        review_rejected?: false,
        train_version: '1.0',
        build_version: '1',
        upload_date: 1
      )
    end
    let(:ready_build) do
      double(
        'Ready Build',
        processed?: true,
        active?: false,
        ready_to_submit?: true,
        export_compliance_missing?: false,
        review_rejected?: false,
        train_version: '1.0',
        build_version: '1',
        upload_date: 1
      )
    end
    let(:future_ready_build) do
      double(
        'Ready Build',
        processed?: true,
        active?: false,
        ready_to_submit?: true,
        export_compliance_missing?: false,
        review_rejected?: false,
        train_version: '1.0',
        build_version: '2',
        upload_date: 2
      )
    end
    let(:export_compliance_required_build) do
      double(
        'Export Compliance Required Build',
        processed?: true,
        active?: false,
        ready_to_submit?: false,
        export_compliance_missing?: true,
        review_rejected?: false,
        train_version: '1.0',
        build_version: '1',
        upload_date: 1
      )
    end
    let(:review_rejected_build) do
      double(
        'Review Rejected Build',
        processed?: true,
        active?: false,
        ready_to_submit?: false,
        export_compliance_missing?: false,
        review_rejected?: true,
        train_version: '1.0',
        build_version: '1',
        upload_date: 1
      )
    end

    it 'returns an already-active build' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([active_build])

      expect(UI).to receive(:success).with("Build #{active_build.train_version} - #{active_build.build_version} is already being tested")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(active_build)
    end

    it 'returns an review rejected build' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([review_rejected_build])

      expect(UI).to receive(:success).with("Successfully finished processing the build #{review_rejected_build.train_version} - #{review_rejected_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(review_rejected_build)
    end

    it 'returns a ready to submit build' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([ready_build])

      expect(UI).to receive(:success).with("Successfully finished processing the build #{ready_build.train_version} - #{ready_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(ready_build)
    end

    it 'returns a ready to submit build when old build is still processing' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([ready_build, future_ready_build])

      expect(UI).to receive(:success).with("Successfully finished processing the build #{ready_build.train_version} - #{ready_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(ready_build)
    end

    it 'returns watched build when there is newer build available' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([old_processing_build, ready_build])

      expect(UI).to receive(:success).with("Successfully finished processing the build #{ready_build.train_version} - #{ready_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(ready_build)
    end

    it 'returns a export-compliance-missing build' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([export_compliance_required_build])

      expect(UI).to receive(:success).with("Successfully finished processing the build #{export_compliance_required_build.train_version} - #{export_compliance_required_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(export_compliance_required_build)
    end

    it 'waits when a build is still processing' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([processing_build], [ready_build])
      expect(FastlaneCore::BuildWatcher).to receive(:sleep)

      expect(UI).to receive(:message).with("Waiting for iTunes Connect to finish processing the new build (#{ready_build.train_version} - #{ready_build.build_version})")
      expect(UI).to receive(:success).with("Successfully finished processing the build #{ready_build.train_version} - #{ready_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(ready_build)
    end

    it 'waits when the build disappears' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([], [ready_build])
      expect(FastlaneCore::BuildWatcher).to receive(:sleep)

      expect(UI).to receive(:message).with("Build doesn't show up in the build list anymore, waiting for it to appear again")
      expect(UI).to receive(:success).with("Successfully finished processing the build #{ready_build.train_version} - #{ready_build.build_version}")
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')

      expect(found_build).to eq(ready_build)
    end

    it 'sleeps 10 seconds by default' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([], [ready_build])
      expect(FastlaneCore::BuildWatcher).to receive(:sleep).with(10)

      allow(UI).to receive(:message)
      allow(UI).to receive(:success)
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1')
    end

    it 'sleeps for the amount of time specified in poll_interval' do
      expect(Spaceship::TestFlight::Build).to receive(:builds_for_train).and_return([], [ready_build])
      expect(FastlaneCore::BuildWatcher).to receive(:sleep).with(123)

      allow(UI).to receive(:message)
      allow(UI).to receive(:success)
      found_build = FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(app_id: 'some-app-id', platform: :ios, train_version: '1.0', build_version: '1', poll_interval: 123)
    end
  end
end
