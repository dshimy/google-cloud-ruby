# Copyright 2014 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google/cloud/env"
require "google/cloud/storage/errors"
require "google/cloud/storage/service"
require "google/cloud/storage/credentials"
require "google/cloud/storage/bucket"
require "google/cloud/storage/bucket/cors"
require "google/cloud/storage/file"

module Google
  module Cloud
    module Storage
      ##
      # # Project
      #
      # Represents the project that storage buckets and files belong to.
      # All data in Google Cloud Storage belongs inside a project.
      # A project consists of a set of users, a set of APIs, billing,
      # authentication, and monitoring settings for those APIs.
      #
      # Google::Cloud::Storage::Project is the main object for interacting with
      # Google Storage. {Google::Cloud::Storage::Bucket} objects are created,
      # read, updated, and deleted by Google::Cloud::Storage::Project.
      #
      # See {Google::Cloud#storage}
      #
      # @example
      #   require "google/cloud/storage"
      #
      #   storage = Google::Cloud::Storage.new
      #
      #   bucket = storage.bucket "my-bucket"
      #   file = bucket.file "path/to/my-file.ext"
      #
      class Project
        ##
        # @private The Service object.
        attr_accessor :service

        ##
        # @private Creates a new Project instance.
        #
        # See {Google::Cloud#storage}
        def initialize service
          @service = service
        end

        ##
        # The Storage project connected to.
        #
        # @example
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new(
        #     project_id: "my-project",
        #     credentials: "/path/to/keyfile.json"
        #   )
        #
        #   storage.project_id #=> "my-project"
        #
        def project_id
          service.project
        end
        alias_method :project, :project_id

        ##
        # @private Default project.
        def self.default_project_id
          ENV["STORAGE_PROJECT"] ||
            ENV["GOOGLE_CLOUD_PROJECT"] ||
            ENV["GCLOUD_PROJECT"] ||
            Google::Cloud.env.project_id
        end

        ##
        # Retrieves a list of buckets for the given project.
        #
        # @param [String] prefix Filter results to buckets whose names begin
        #   with this prefix.
        # @param [String] token A previously-returned page token representing
        #   part of the larger set of results to view.
        # @param [Integer] max Maximum number of buckets to return.
        # @param [Boolean, String] user_project If this parameter is set to
        #   `true`, transit costs for operations on the enabled buckets or their
        #   files will be billed to the current project for this client. (See
        #   {#project} for the ID of the current project.) If this parameter is
        #   set to a project ID other than the current project, and that project
        #   is authorized for the currently authenticated service account,
        #   transit costs will be billed to the given project. This parameter is
        #   required with requester pays-enabled buckets. The default is `nil`.
        #
        #   The value provided will be applied to all operations on the returned
        #   bucket instances and their files.
        #
        #   See also {Bucket#requester_pays=} and {Bucket#requester_pays}.
        #
        # @return [Array<Google::Cloud::Storage::Bucket>] (See
        #   {Google::Cloud::Storage::Bucket::List})
        #
        # @example
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   buckets = storage.buckets
        #   buckets.each do |bucket|
        #     puts bucket.name
        #   end
        #
        # @example Retrieve buckets with names that begin with a given prefix:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   user_buckets = storage.buckets prefix: "user-"
        #   user_buckets.each do |bucket|
        #     puts bucket.name
        #   end
        #
        # @example Retrieve all buckets: (See {Bucket::List#all})
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   buckets = storage.buckets
        #   buckets.all do |bucket|
        #     puts bucket.name
        #   end
        #
        def buckets prefix: nil, token: nil, max: nil, user_project: nil
          gapi = service.list_buckets \
            prefix: prefix, token: token, max: max, user_project: user_project
          Bucket::List.from_gapi \
            gapi, service, prefix, max, user_project: user_project
        end
        alias_method :find_buckets, :buckets

        ##
        # Retrieves bucket by name.
        #
        # @param [String] bucket_name Name of a bucket.
        # @param [Boolean] skip_lookup Optionally create a Bucket object
        #   without verifying the bucket resource exists on the Storage service.
        #   Calls made on this object will raise errors if the bucket resource
        #   does not exist. Default is `false`.
        # @param [Boolean, String] user_project If this parameter is set to
        #   `true`, transit costs for operations on the requested bucket or a
        #   file it contains will be billed to the current project for this
        #   client. (See {#project} for the ID of the current project.) If this
        #   parameter is set to a project ID other than the current project, and
        #   that project is authorized for the currently authenticated service
        #   account, transit costs will be billed to the given project. This
        #   parameter is required with requester pays-enabled buckets. The
        #   default is `nil`.
        #
        #   The value provided will be applied to all operations on the returned
        #   bucket instance and its files.
        #
        #   See also {Bucket#requester_pays=} and {Bucket#requester_pays}.
        #
        # @return [Google::Cloud::Storage::Bucket, nil] Returns nil if bucket
        #   does not exist
        #
        # @example
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket = storage.bucket "my-bucket"
        #   puts bucket.name
        #
        # @example With `user_project` set to bill costs to the default project:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket = storage.bucket "other-project-bucket", user_project: true
        #   files = bucket.files # Billed to current project
        #
        # @example With `user_project` set to a project other than the default:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket = storage.bucket "other-project-bucket",
        #                           user_project: "my-other-project"
        #   files = bucket.files # Billed to "my-other-project"
        #
        def bucket bucket_name, skip_lookup: false, user_project: nil
          if skip_lookup
            return Bucket.new_lazy bucket_name, service,
                                   user_project: user_project
          end
          gapi = service.get_bucket bucket_name, user_project: user_project
          Bucket.from_gapi gapi, service, user_project: user_project
        rescue Google::Cloud::NotFoundError
          nil
        end
        alias_method :find_bucket, :bucket

        ##
        # Creates a new bucket with optional attributes. Also accepts a block
        # for defining the CORS configuration for a static website served from
        # the bucket. See {Bucket::Cors} for details.
        #
        # The API call to create the bucket may be retried under certain
        # conditions. See {Google::Cloud#storage} to control this behavior.
        #
        # You can pass [website
        # settings](https://cloud.google.com/storage/docs/website-configuration)
        # for the bucket, including a block that defines CORS rule. See
        # {Bucket::Cors} for details.
        #
        # @see https://cloud.google.com/storage/docs/cross-origin Cross-Origin
        #   Resource Sharing (CORS)
        # @see https://cloud.google.com/storage/docs/website-configuration How
        #   to Host a Static Website
        #
        # @param [String] bucket_name Name of a bucket.
        # @param [String] acl Apply a predefined set of access controls to this
        #   bucket.
        #
        #   Acceptable values are:
        #
        #   * `auth`, `auth_read`, `authenticated`, `authenticated_read`,
        #     `authenticatedRead` - Project team owners get OWNER access, and
        #     allAuthenticatedUsers get READER access.
        #   * `private` - Project team owners get OWNER access.
        #   * `project_private`, `projectPrivate` - Project team members get
        #     access according to their roles.
        #   * `public`, `public_read`, `publicRead` - Project team owners get
        #     OWNER access, and allUsers get READER access.
        #   * `public_write`, `publicReadWrite` - Project team owners get OWNER
        #     access, and allUsers get WRITER access.
        # @param [String] default_acl Apply a predefined set of default object
        #   access controls to this bucket.
        #
        #   Acceptable values are:
        #
        #   * `auth`, `auth_read`, `authenticated`, `authenticated_read`,
        #     `authenticatedRead` - File owner gets OWNER access, and
        #     allAuthenticatedUsers get READER access.
        #   * `owner_full`, `bucketOwnerFullControl` - File owner gets OWNER
        #     access, and project team owners get OWNER access.
        #   * `owner_read`, `bucketOwnerRead` - File owner gets OWNER access,
        #     and project team owners get READER access.
        #   * `private` - File owner gets OWNER access.
        #   * `project_private`, `projectPrivate` - File owner gets OWNER
        #     access, and project team members get access according to their
        #     roles.
        #   * `public`, `public_read`, `publicRead` - File owner gets OWNER
        #     access, and allUsers get READER access.
        # @param [String] location The location of the bucket. Object data for
        #   objects in the bucket resides in physical storage within this
        #   region. Possible values include `ASIA`, `EU`, and `US`. (See the
        #   [developer's
        #   guide](https://cloud.google.com/storage/docs/bucket-locations) for
        #   the authoritative list. The default value is `US`.
        # @param [String] logging_bucket The destination bucket for the bucket's
        #   logs. For more information, see [Access
        #   Logs](https://cloud.google.com/storage/docs/access-logs).
        # @param [String] logging_prefix The prefix used to create log object
        #   names for the bucket. It can be at most 900 characters and must be a
        #   [valid object
        #   name](https://cloud.google.com/storage/docs/bucket-naming#objectnames)
        #   . By default, the object prefix is the name of the bucket for which
        #   the logs are enabled. For more information, see [Access
        #   Logs](https://cloud.google.com/storage/docs/access-logs).
        # @param [Symbol, String] storage_class Defines how objects in the
        #   bucket are stored and determines the SLA and the cost of storage.
        #   Accepted values include `:multi_regional`, `:regional`, `:nearline`,
        #   and `:coldline`, as well as the equivalent strings returned by
        #   {Bucket#storage_class}. For more information, see [Storage
        #   Classes](https://cloud.google.com/storage/docs/storage-classes). The
        #   default value is the Standard storage class, which is equivalent to
        #   `:multi_regional` or `:regional` depending on the bucket's location
        #   settings.
        # @param [Boolean] versioning Whether [Object
        #   Versioning](https://cloud.google.com/storage/docs/object-versioning)
        #   is to be enabled for the bucket. The default value is `false`.
        # @param [String] website_main The index page returned from a static
        #   website served from the bucket when a site visitor requests the top
        #   level directory. For more information, see [How to Host a Static
        #   Website
        #   ](https://cloud.google.com/storage/docs/website-configuration#step4).
        # @param [String] website_404 The page returned from a static website
        #   served from the bucket when a site visitor requests a resource that
        #   does not exist. For more information, see [How to Host a Static
        #   Website
        #   ](https://cloud.google.com/storage/docs/website-configuration#step4).
        # @param [String] user_project If this parameter is set to a project ID
        #   other than the current project, and that project is authorized for
        #   the currently authenticated service account, transit costs will be
        #   billed to the given project. The default is `nil`.
        #
        #   The value provided will be applied to all operations on the returned
        #   bucket instance and its files.
        #
        #   See also {Bucket#requester_pays=} and {Bucket#requester_pays}.
        #
        # @yield [bucket] a block for configuring the bucket before it is
        #   created
        # @yieldparam [Bucket] cors the bucket object to be configured
        #
        # @return [Google::Cloud::Storage::Bucket]
        #
        # @example
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket = storage.create_bucket "my-bucket"
        #
        # @example Configure the bucket in a block:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket = storage.create_bucket "my-bucket" do |b|
        #     b.website_main = "index.html"
        #     b.website_404 = "not_found.html"
        #     b.requester_pays = true
        #     b.cors.add_rule ["http://example.org", "https://example.org"],
        #                      "*",
        #                      headers: ["X-My-Custom-Header"],
        #                      max_age: 300
        #   end
        #
        def create_bucket bucket_name, acl: nil, default_acl: nil,
                          location: nil, storage_class: nil,
                          logging_bucket: nil, logging_prefix: nil,
                          website_main: nil, website_404: nil, versioning: nil,
                          requester_pays: nil, user_project: nil
          new_bucket = Google::Apis::StorageV1::Bucket.new({
            name: bucket_name,
            location: location
          }.delete_if { |_, v| v.nil? })
          storage_class = storage_class_for(storage_class)
          updater = Bucket::Updater.new(new_bucket).tap do |b|
            b.logging_bucket = logging_bucket unless logging_bucket.nil?
            b.logging_prefix = logging_prefix unless logging_prefix.nil?
            b.storage_class = storage_class unless storage_class.nil?
            b.website_main = website_main unless website_main.nil?
            b.website_404 = website_404 unless website_404.nil?
            b.versioning = versioning unless versioning.nil?
            b.requester_pays = requester_pays unless requester_pays.nil?
          end
          yield updater if block_given?
          updater.check_for_changed_labels!
          updater.check_for_mutable_cors!
          gapi = service.insert_bucket \
            new_bucket, acl: acl_rule(acl), default_acl: acl_rule(default_acl),
                        user_project: user_project
          Bucket.from_gapi gapi, service, user_project: user_project
        end

        ##
        # Access without authentication can be granted to a File for a specified
        # period of time. This URL uses a cryptographic signature of your
        # credentials to access the file identified by `path`. A URL can be
        # created for paths that do not yet exist. For instance, a URL can be
        # created to `PUT` file contents to.
        #
        # Generating a URL requires service account credentials, either by
        # connecting with a service account when calling
        # {Google::Cloud.storage}, or by passing in the service account `issuer`
        # and `signing_key` values. Although the private key can be passed as a
        # string for convenience, creating and storing an instance of
        # `OpenSSL::PKey::RSA` is more efficient when making multiple calls to
        # `signed_url`.
        #
        # A {SignedUrlUnavailable} is raised if the service account credentials
        # are missing. Service account credentials are acquired by following the
        # steps in [Service Account Authentication](
        # https://cloud.google.com/storage/docs/authentication#service_accounts).
        #
        # @see https://cloud.google.com/storage/docs/access-control#Signed-URLs
        #   Access Control Signed URLs guide
        #
        # @param [String] bucket Name of the bucket.
        # @param [String] path Path to the file in Google Cloud Storage.
        # @param [String] method The HTTP verb to be used with the signed URL.
        #   Signed URLs can be used
        #   with `GET`, `HEAD`, `PUT`, and `DELETE` requests. Default is `GET`.
        # @param [Integer] expires The number of seconds until the URL expires.
        #   Default is 300/5 minutes.
        # @param [String] content_type When provided, the client (browser) must
        #   send this value in the HTTP header. e.g. `text/plain`
        # @param [String] content_md5 The MD5 digest value in base64. If you
        #   provide this in the string, the client (usually a browser) must
        #   provide this HTTP header with this same value in its request.
        # @param [Hash] headers Google extension headers (custom HTTP headers
        #   that begin with `x-goog-`) that must be included in requests that
        #   use the signed URL.
        # @param [String] issuer Service Account's Client Email.
        # @param [String] client_email Service Account's Client Email.
        # @param [OpenSSL::PKey::RSA, String] signing_key Service Account's
        #   Private Key.
        # @param [OpenSSL::PKey::RSA, String] private_key Service Account's
        #   Private Key.
        # @param [Hash] query Query string parameters to include in the signed
        #   URL. The given parameters are not verified by the signature.
        #
        #   Parameters such as `response-content-disposition` and
        #   `response-content-type` can alter the behavior of the response when
        #   using the URL, but only when the file resource is missing the
        #   corresponding values. (These values can be permanently set using
        #   {File#content_disposition=} and {File#content_type=}.)
        #
        # @example
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket_name = "my-todo-app"
        #   file_path = "avatars/heidi/400x400.png"
        #   shared_url = storage.signed_url bucket_name, file_path
        #
        # @example Any of the option parameters may be specified:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud::Storage.new
        #
        #   bucket_name = "my-todo-app"
        #   file_path = "avatars/heidi/400x400.png"
        #   shared_url = storage.signed_url bucket_name, file_path,
        #                                   method: "PUT",
        #                                   content_type: "image/png",
        #                                   expires: 300 # 5 minutes from now
        #
        # @example Using the issuer and signing_key options:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud.storage
        #
        #   bucket_name = "my-todo-app"
        #   file_path = "avatars/heidi/400x400.png"
        #   issuer_email = "service-account@gcloud.com"
        #   key = OpenSSL::PKey::RSA.new "-----BEGIN PRIVATE KEY-----\n..."
        #   shared_url = storage.signed_url bucket_name, file_path,
        #                                   issuer: issuer_email,
        #                                   signing_key: key
        #
        # @example Using the headers option:
        #   require "google/cloud/storage"
        #
        #   storage = Google::Cloud.storage
        #
        #   bucket_name = "my-todo-app"
        #   file_path = "avatars/heidi/400x400.png"
        #   shared_url = storage.signed_url bucket_name, file_path,
        #                                   headers: {
        #                                     "x-goog-acl" => "private",
        #                                     "x-goog-meta-foo" => "bar,baz"
        #                                   }
        #
        def signed_url bucket, path, method: nil, expires: nil,
                       content_type: nil, content_md5: nil, headers: nil,
                       issuer: nil, client_email: nil, signing_key: nil,
                       private_key: nil, query: nil
          signer = File::Signer.new bucket, path, service
          signer.signed_url method: method, expires: expires, headers: headers,
                            content_type: content_type,
                            content_md5: content_md5,
                            issuer: issuer, client_email: client_email,
                            signing_key: signing_key, private_key: private_key,
                            query: query
        end

        protected

        def acl_rule option_name
          Bucket::Acl.predefined_rule_for option_name
        end

        def storage_class_for str
          return nil if str.nil?
          { "durable_reduced_availability" => "DURABLE_REDUCED_AVAILABILITY",
            "dra" => "DURABLE_REDUCED_AVAILABILITY",
            "durable" => "DURABLE_REDUCED_AVAILABILITY",
            "nearline" => "NEARLINE",
            "coldline" => "COLDLINE",
            "multi_regional" => "MULTI_REGIONAL",
            "regional" => "REGIONAL",
            "standard" => "STANDARD" }[str.to_s.downcase] || str.to_s
        end
      end
    end
  end
end