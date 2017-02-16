#!/usr/bin/perl

# @author: VMware, Inc.
# @copyright: copyright 2016, 2017 VMware, Inc.  All rights reserved.
# @vcenter version: 6.5+

#
# Perl Core Modules
#
use strict;
use Getopt::Long;

#
# VMware runtime library
#
use Com::Vmware::Vapi::Util::Logger
  qw(log_info log_dumper log_framework log_warning set_verbosity);

#
# Sample helper module
#
use Common::SampleBase;

#
# Generated SDK's
#
use Com::Vmware::Cis::Session;
use Com::Vmware::Vcenter::Vm::GuestOS;
use Com::Vmware::Vcenter::VM;
use Com::Vmware::Vcenter::Vm::Power;
use Com::Vmware::Vcenter::Vm::Hardware;
use Com::Vmware::Vcenter::Vm::Hardware::Adapter::Scsi;
use Com::Vmware::Vcenter::Vm::Hardware::Disk;
use Com::Vmware::Vcenter::Vm::Hardware::ScsiAddressSpec;
use Com::Vmware::Vcenter::Vm::Hardware::Ethernet;
use Com::Vmware::Vcenter::Vm::Hardware::Boot;
use Com::Vmware::Vcenter::Vm::Hardware::Boot::Device;
use Com::Vmware::Vcenter::Vm::Hardware::Cdrom;
use Com::Vmware::Vcenter::Vm::Hardware::Cpu;
use Com::Vmware::Vcenter::Vm::Hardware::Memory;

#
# Sample helper modules
#
use Vcenter::Helpers::PlacementHelper;
use Vcenter::Helpers::NetworkHelper;

# Set the logger level
set_verbosity( 'level' => 3 );

# Initialize the global variable
my (
   %params,         $sampleBase, $vmfolder_name,   $cluster_name,
   $stubFactory,    $stubConfig, $datacenter_name, $vm_service,
   $datastore_name, $defaultVMId
) = ();
my $DEFAULT_VM_NAME = "Sample-Default-VM";
my $vmGuestOS       = Com::Vmware::Vcenter::Vm::GuestOS::WINDOWS_9_64;

# Declare the mandatory parameter list
my @required_options = (
   'username',   'password',    'lsurl',    'server',
   'datacenter', 'clustername', 'vmfolder', 'datastore',
   'cleanup'
);

sub init {

   #
   # User inputs
   #
   GetOptions(
      \%params,     "server=s",     "lsurl=s",       "username=s",
      "password=s", "privatekey:s", "servercert:s",  "cert:s",
      "vmfolder:s", "datastore:s",  "clustername:s", "datacenter:s",
      "mgmtnode:s",
      "cleanup:s", "help:s"
     )
     or die
"\nValid options are --server <server> --username <user> --password <password> --lsurl <lookup service url>
                         --privatekey <private key> --servercert <server cert> --cert <cert> --vmfolder <vmfolder name> --datastore <datastore name> --clustername <cluster name> --datacenter <datacenter name> --cleanup <value should be true or false> or --help\n";

   if ( defined( $params{'help'} ) ) {
      print "\nCommand to execute sample:\n";
      print
"default_vm.pl --server <server> --username <user> --password <password> --lsurl <lookup service url> \n";
      print
"               --privatekey <private key> --servercert <server cert> --cert <cert> --vmfolder <vmfolder name> --datastore <datastore name> --clustername <cluster name> --datacenter <datacenter name> --cleanup <value should be true or false> \n";
      exit;
   }

   my $mandatory_params_list = 'Missing mandatory parameter(s) i.e. ';
   my $flag                  = 0;
   foreach (@required_options) {
      if ( !defined( $params{$_} ) ) {
         $flag = 1;
         $mandatory_params_list =
           ' ' . $mandatory_params_list . '--' . $_ . ', ';
      }
   }
   if ( $flag == 1 ) {
      print $mandatory_params_list;
      exit;
   }

   $datacenter_name = $params{'datacenter'};
   $cluster_name    = $params{'clustername'};
   $vmfolder_name   = $params{'vmfolder'};
   $datastore_name  = $params{'datastore'};

   $sampleBase  = new Common::SampleBase( 'params' => \%params );
   $stubConfig  = $sampleBase->{'stub_config'};
   $stubFactory = $sampleBase->{'stub_factory'};
}

sub setup {

   #
   # Get the VM Service
   #
   log_info( MSG => "Creating VM Service..." );
   $vm_service = $stubFactory->create_stub(
      'service_name' => 'Com::Vmware::Vcenter::VM',
      'stub_config'  => $stubConfig
   );
}

sub run {

   #Get a placement spec
   my $vmPlacementSpec =
     Vcenter::Helpers::PlacementHelper::getPlacementSpecForCluster(
      'stubFactory'       => $stubFactory,
      'sessionStubConfig' => $stubConfig,
      'datacenterName'    => $datacenter_name,
      'clusterName'       => $cluster_name,
      'vmFolderName'      => $vmfolder_name,
      'datastoreName'     => $datastore_name
     );

   # Create the VM
   createDefaultVM( 'vmPlacementSpec' => $vmPlacementSpec );
}

#
# Creates a VM on a cluster with selected Guest OS and name which
# uses all the system provided defaults.
#
sub createDefaultVM() {
   my (%args)          = @_;
   my $vmPlacementSpec = $args{'vmPlacementSpec'};
   my $vm_createspec   = new Com::Vmware::Vcenter::VM::CreateSpec();
   $vm_createspec->set_guest_OS( 'guest_OS' => $vmGuestOS );
   $vm_createspec->set_name( 'name' => $DEFAULT_VM_NAME );
   $vm_createspec->set_placement( 'placement' => $vmPlacementSpec );
   log_info( MSG => "#### Example: Creating default VM with spec: '"
        . $vm_createspec
        . "'" );
   $defaultVMId = $vm_service->create( 'spec' => $vm_createspec );
   log_info( MSG => "Created default VM : '"
        . $DEFAULT_VM_NAME
        . "' with id: '"
        . $defaultVMId
        . "'" );
   my $vmInfo = $vm_service->get( 'vm' => $defaultVMId );

   #print Dumper($vmInfo);
   log_info( MSG => "Default VM Info:" );
   log_info( MSG => "   VM name:'" . $vmInfo->get_name() . "'" );
   log_info( MSG => "   VM Guest OS:'" . $vmInfo->get_guest_OS() . "'" );
}

#
# Cleanup any data created by the sample run, if cleanup=true
#
sub cleanup() {
   log_info( MSG => "#### Deleting the Default VM" );
   if ( defined($defaultVMId) ) {
      $vm_service->delete( 'vm' => $defaultVMId );
   }
}

#
# Demonstrates how to create a VM with system provided defaults
#
# Sample Prerequisites:
# The sample needs a datacenter and the following resources:
# - vm folder
# - datastore
# - cluster
#

# Call main
&main();

sub main() {
   init();
   setup();
   run();
   if ( $params{cleanup} eq 'true' ) {
      cleanup();
   }
   log_info( MSG => "#### Done!" );
}

# END