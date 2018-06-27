require 'spec_helper'

RSpec.describe 'Legacy Jobs' do
  describe ::BlobstoreDelete, job_context: :worker do
    subject { ::BlobstoreDelete.new('key', 'blobstore-name') }
    it { is_expected.to be_a(CloudController::Jobs::Runtime::BlobstoreDelete) }
  end

  describe ::BlobstoreUpload do
    subject { ::BlobstoreUpload.new('/a/b', 'blobstore_key', 'blobstore_name') }
    it { is_expected.to be_a(CloudController::Jobs::Runtime::BlobstoreUpload) }
  end

  describe ::ModelDeletionJob do
    subject { ::ModelDeletionJob.new(CloudController::Space, 'space-guid') }
    it { is_expected.to be_a(CloudController::Jobs::Runtime::ModelDeletion) }
  end
end
