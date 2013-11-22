require 'rcs-common/trace'

module RCS
  module Common
    module Rest
      STATUS_OK = 200
      STATUS_REDIRECT = 302
      STATUS_BAD_REQUEST = 400
      STATUS_NOT_FOUND = 404
      STATUS_NOT_AUTHORIZED = 403
      STATUS_METHOD_NOT_ALLOWED = 405
      STATUS_CONFLICT = 409
      STATUS_SERVER_ERROR = 500
    end
  end
end
