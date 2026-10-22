require 'rails_helper'
require 'open3'

# The systemd units that run the nightly backup on the servers, and the
# script that installs them (bin/install-admissions-timers).
RSpec.describe 'The admissions backup timer' do
  let(:dir) { Rails.root.join('systemd') }
  let(:service) { dir.join('nwspk-admissions-backup.service').read }
  let(:timer) { dir.join('nwspk-admissions-backup.timer').read }
  let(:script) { Rails.root.join('bin/install-admissions-timers').to_s }

  it 'runs the nightly task as deploy, in the checkout, reading .envrc and the rbenv shims' do
    exec_start = service[/^ExecStart=(.*)$/, 1]
    expect(exec_start).to include('source .envrc', '/home/deploy/.rbenv/shims:$$PATH',
                                  'bundle exec rails admissions:backup:nightly')
    expect(service).to include("Type=oneshot\n", "WorkingDirectory=/var/www/web\n", "User=deploy\n",
                               "StandardOutput=journal\n")
    Rails.application.load_tasks unless Rake::Task.task_defined?('admissions:backup:nightly')
    expect(Rake::Task.task_defined?('admissions:backup:nightly')).to be true
  end

  it 'fires daily at 02:30 London time, catching up a missed night' do
    expect(timer).to include("OnCalendar=*-*-* 02:30:00 Europe/London\n", "Persistent=true\n",
                             "Unit=nwspk-admissions-backup.service\n", "WantedBy=timers.target\n")
  end

  it 'parses cleanly, where systemd-analyze is available' do
    skip 'systemd-analyze is not installed' unless system('command -v systemd-analyze >/dev/null')
    out, status = Open3.capture2e('systemd-analyze', 'verify', dir.join('nwspk-admissions-backup.service').to_s,
                                  dir.join('nwspk-admissions-backup.timer').to_s)
    expect(status).to be_success
    expect(out).to eq ''
  end

  it 'has an install script whose dry run prints every step and changes nothing' do
    target = Dir.mktmpdir
    out, status = Open3.capture2e({ 'ADMISSIONS_TIMERS_TARGET' => target }, script, '--dry-run')
    expect(status).to be_success
    expect(out.scan(/^==> .*/)).to eq ['==> Checking the units', "==> Copying the units to #{target}",
                                       '==> Reloading systemd',
                                       '==> Enabling and starting the timer (this runs no backup now)',
                                       '==> The timer']
    expect(out).to include('would run: systemctl enable --now nwspk-admissions-backup.timer',
                           'would run: systemctl list-timers --all nwspk-admissions-backup.timer')
    expect(out).not_to include('admissions:backup:nightly', 'systemctl start')
    expect(Dir.children(target)).to be_empty
  ensure
    FileUtils.remove_entry(target)
  end

  it 'says an installed, unchanged unit is left alone' do
    target = Dir.mktmpdir
    FileUtils.cp(dir.join('nwspk-admissions-backup.timer'), target)
    out, = Open3.capture2e({ 'ADMISSIONS_TIMERS_TARGET' => target }, script, '--dry-run')
    expect(out).to include('nwspk-admissions-backup.timer is already installed and unchanged',
                           "would run: install -m 0644 #{dir}/nwspk-admissions-backup.service")
  ensure
    FileUtils.remove_entry(target)
  end

  it 'refuses an unknown argument' do
    out, status = Open3.capture2e(script, '--now')
    expect(status.exitstatus).to eq 2
    expect(out).to include('Usage:')
  end
end
