# It"s important to keep around old jobs names since there might be queued jobs with these older names
# in a deployment out there. This is especially important for on-prem deployments that might not regularly
# update CF.

require 'jobs/runtime/blobstore_delete'
require 'jobs/runtime/blobstore_upload'
require 'jobs/runtime/model_deletion'

BlobstoreDelete = CloudController::Jobs::Runtime::BlobstoreDelete
BlobstoreUpload = CloudController::Jobs::Runtime::BlobstoreUpload
ModelDeletionJob = CloudController::Jobs::Runtime::ModelDeletion
