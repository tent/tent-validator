module TentD
  module Model

    # Automigrate custom fields
    unless ([:public_id] - User.columns).empty?
      User.db.alter_table(:users) do
        add_column :public_id, 'text', :null => false
      end

      # Load newly created columns
      User.send(:set_columns, User.db[:users].naked.columns)
    end

    # Reopen class from tentd
    class User

      def self.generate
        public_id = TentD::Utils.random_id
        db.transaction do
          user = create(
            :public_id => public_id,
            :entity => entity_from_public_id(public_id),
          )
        end
      end

      def self.entity_from_public_id(public_id)
        "http://localhost:#{TentValidator.local_server_port}/#{public_id}/tent"
      end

    end

  end
end
