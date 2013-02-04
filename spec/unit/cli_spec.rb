# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Bootstrap do
  include FileUtils

  before do
    ENV['MANIFEST'] = File.expand_path("../../../tmp/test-manifest.yml", __FILE__)
    rm_rf(ENV['MANIFEST'])
    @cmd = Bosh::Bootstrap::Cli.new
  end

  # stub out all stages except a specific one
  # +stage+ can either be the stage number or name
  def testing_stage(stage)
    stage_methods = %w[
      deploy_stage_1_choose_infrastructure_provider
      deploy_stage_2_bosh_configuration
      deploy_stage_3_create_allocate_inception_vm
      deploy_stage_4_prepare_inception_vm
      deploy_stage_5_deploy_micro_bosh
      deploy_stage_6_setup_new_bosh
    ]
    stage_methods.each do |method|
      unless method =~ /#{stage}/
        @cmd.should_receive(method.to_sym)
      end
    end
  end

  def setting(key, value)
    @cmd.settings[key] = value
  end

  describe "deploy" do
    it "goes through stages" do
      @cmd.should_receive(:deploy_stage_1_choose_infrastructure_provider)
      @cmd.should_receive(:deploy_stage_2_bosh_configuration)
      @cmd.should_receive(:deploy_stage_3_create_allocate_inception_vm)
      @cmd.should_receive(:deploy_stage_4_prepare_inception_vm)
      @cmd.should_receive(:deploy_stage_5_deploy_micro_bosh)
      @cmd.should_receive(:deploy_stage_6_setup_new_bosh)
      @cmd.deploy
    end

    it "stage 6 - sets up new microbosh" do
      testing_stage(6)
      setting "bosh_name", "microbosh-aws-us-east-1"
      setting "bosh_username", "drnic"
      setting "bosh_password", "password"
      setting "bosh", {}
      @cmd.settings["bosh"]["ip_address"] = "1.2.3.4"
      @cmd.should_receive(:sleep)
      @cmd.should_receive(:run_server).and_return(true)
      @cmd.should_receive(:sh).with("bosh -u drnic -p password target 1.2.3.4")
      @cmd.should_receive(:sh).with("bosh login drnic password")
      @cmd.deploy
    end
  end

  describe "micro_bosh_stemcell_name" do
    # The +bosh_stemcells_cmd+ has an output that looks like:
    # +-----------------------------------+--------------------+
    # | Name                              | Tags               |
    # +-----------------------------------+--------------------+
    # | micro-bosh-stemcell-aws-0.6.4.tgz | aws, micro, stable |
    # | micro-bosh-stemcell-aws-0.7.0.tgz | aws, micro, test   |
    # | micro-bosh-stemcell-aws-0.8.1.tgz | aws, micro, test   |
    # +-----------------------------------+--------------------+
    #
    # So to get the latest version for the filter tags,
    # get the Name field, reverse sort, and return the first item
    it "should return the latest stable stemcell by default for AWS" do
      @cmd.settings["bosh_provider"] = "aws"
      @cmd.should_receive(:`).
        with("bosh public stemcells --tags micro,aws").
        and_return(File.read(spec_asset("bosh/public_stemcells/aws_micro.out")))
      @cmd.micro_bosh_stemcell_name.should == "micro-bosh-stemcell-aws-0.8.1.tgz"
    end
  end

end
