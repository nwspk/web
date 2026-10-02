# admit phase 0b: round settings (SPEC §2 round-config, §3a email modes).
class AddSettingsToAdmissionsRounds < ActiveRecord::Migration[7.2]
  def change
    change_table :admissions_rounds, bulk: true do |t|
      # Money in pence, as the site keeps it elsewhere (plans.value).
      t.integer :programme_fee_pence
      t.integer :accommodation_monthly_pence
      t.integer :scholarship_pot_pence
      # { email type => mode }; a type not listed is on ask_me_first.
      t.jsonb :email_modes, null: false, default: {}
      # { staff-waiting stage => days }; a stage not listed takes 7.
      t.jsonb :staff_turnaround_days, null: false, default: {}
      t.integer :reminder_interval_days, null: false, default: 7
    end
  end
end
