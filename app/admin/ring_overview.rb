ActiveAdmin.register_page 'RingOverview' do
  menu label: 'Ring overview'

  content do
    panel 'Users who already have rings' do
      table_for User.with_rings do
        column(:name) { |u| link_to(u.name, admin_user_path(u)) }
        column('Programmed') { |u| u.last_ring_created_at }
        column('Joined') { |u| u.created_at }
      end
    end

    panel 'Users without rings' do
      table_for User.without_rings do
        column(:name) { |u| link_to(u.name, admin_user_path(u)) }
        column('Joined') { |u| u.created_at }
      end
    end
  end
end
