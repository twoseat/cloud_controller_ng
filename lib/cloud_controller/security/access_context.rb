module CloudController
  module Security
    class AccessContext
      include ::Allowy::Context

      attr_reader :queryer

      def initialize(queryer=nil)
        @queryer = queryer
      end

      def admin_override
        CloudController::SecurityContext.admin? || CloudController::SecurityContext.admin_read_only? || CloudController::SecurityContext.global_auditor?
      end

      def roles
        CloudController::SecurityContext.roles
      end

      def user_email
        CloudController::SecurityContext.current_user_email
      end

      def user
        CloudController::SecurityContext.current_user
      end
    end
  end
end
