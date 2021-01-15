module ScimRails
  module ExceptionHandler
    extend ActiveSupport::Concern

    class InvalidCredentials < StandardError
    end

    class InvalidQuery < StandardError
    end

    class NoTarget < StandardError
    end

    class Uniqueness < StandardError
    end

    class UnsupportedPatchRequest < StandardError
    end

    included do
      if Rails.env.production?
        rescue_from StandardError do |exception|
          on_error = ScimRails.config.on_error
          if on_error.respond_to?(:call)
            on_error.call(exception)
          else
            Rails.logger.error(exception.inspect)
          end

          json_response(
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
              status: '500'
            },
            :internal_server_error
          )
        end
      end

      rescue_from ScimRails::ExceptionHandler::InvalidCredentials do
        json_response(
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
            detail:
              'Authorization failure. The authorization header is invalid ' \
              'or missing.',
            status: '401'
          },
          :unauthorized
        )
      end

      rescue_from ScimRails::ExceptionHandler::InvalidQuery do
        json_response(
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
            scimType: 'invalidFilter',
            detail:
              'The specified filter syntax was invalid, or the specified ' \
              'attribute and filter comparison combination is not supported.',
            status: '400'
          },
          :bad_request
        )
      end

      rescue_from ScimRails::ExceptionHandler::NoTarget do
        json_response(
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
            scimType: 'noTarget',
            detail:
              'No path was specified.',
            status: '400'
          },
          :bad_request
        )
      end

      rescue_from ScimRails::ExceptionHandler::Uniqueness do
        json_response(
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
            scimType: 'uniqueness',
            detail:
              'The resource you are trying to create is not unique.',
            status: '409'
          },
          :conflict
        )
      end

      rescue_from ScimRails::ExceptionHandler::UnsupportedPatchRequest do
        json_response(
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
            detail:
              'Invalid PATCH request. ' \
              'Make sure every operation contains a value.',
            status: '422'
          },
          :unprocessable_entity
        )
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        json_response(
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
            detail: "Resource #{e.id} not found.",
            status: '404'
          },
          :not_found
        )
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        case e.message
        when /has already been taken/
          json_response(
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
              detail: e.message,
              status: '409'
            },
            :conflict
          )
        else
          json_response(
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
              detail: e.message,
              status: '422'
            },
            :unprocessable_entity
          )
        end
      end
    end
  end
end
