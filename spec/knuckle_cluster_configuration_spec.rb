require "spec_helper"

RSpec.describe KnuckleCluster::Configuration do

  let(:file)    { File.join(File.dirname(__FILE__), 'fixtures', 'test_data')}
  let(:profile) { 'platform' }

  it "generates correct output using inheritance" do
    expect(KnuckleCluster::Configuration.load_parameters(profile: profile, profile_file: file)).to eq(
      {
        cluster_name: 'pohos_super_cluster',
        bastion: 'mega_awesome_bastion',
        rsa_key_location: '~/.ssh/amazing_rsa_key',
        aws_vault_profile: 'cool_aws_vault_profile',
        ssh_username: 'ubuntu',
        region: 'us-east-1',
        sudo: false
      }
    )
  end

end
