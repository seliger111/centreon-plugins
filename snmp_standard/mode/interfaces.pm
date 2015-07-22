#
# Copyright 2015 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package snmp_standard::mode::interfaces;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::values;
use centreon::plugins::statefile;
use Digest::MD5 qw(md5_hex);

my $instance_mode;

my $maps_counters = {
    int => { 
        '000_status'   => { filter => 'add_status',
            set => {
                key_values => [ { name => 'opstatus' }, { name => 'admstatus' } ],
                closure_custom_calc => \&custom_status_calc,
                closure_custom_output => \&custom_status_output,
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&custom_threshold_output,
            }
        },
        '010_in-traffic'   => { filter => 'add_traffic',
            set => {
                key_values => [ { name => 'in', diff => 1 }, { name => 'speed_in'}, { name => 'display' }, { name => 'mode_traffic' } ],
                per_second => 1,
                closure_custom_calc => \&custom_traffic_calc, closure_custom_calc_extra_options => { label_ref => 'in' },
                closure_custom_output => \&custom_traffic_output,
                closure_custom_perfdata => \&custom_traffic_perfdata,
                closure_custom_threshold_check => \&custom_traffic_threshold,
            }
        },
        '011_out-traffic'   => { filter => 'add_traffic',
            set => {
                key_values => [ { name => 'out', diff => 1 }, { name => 'speed_out'}, { name => 'display' }, { name => 'mode_traffic' } ],
                per_second => 1,
                closure_custom_calc => \&custom_traffic_calc, closure_custom_calc_extra_options => { label_ref => 'out' },
                closure_custom_output => \&custom_traffic_output,
                closure_custom_perfdata => \&custom_traffic_perfdata,
                closure_custom_threshold_check => \&custom_traffic_threshold,
            }
        },
        '020_in-ucast'   => { filter => 'add_cast',
            set => {
                key_values => [ { name => 'iucast', diff => 1 }, { name => 'imcast', diff => 1 }, { name => 'ibcast', diff => 1 }, { name => 'display' }, { name => 'mode_cast' } ],
                closure_custom_calc => \&custom_cast_calc, closure_custom_calc_extra_options => { label_ref => 'iucast', total_ref1 => 'ibcast', total_ref2 => 'imcast' },
                output_template => 'In Ucast : %.2f %%', output_error_template => 'In Ucast : %s',
                output_use => 'iucast_prct',  threshold_use => 'iucast_prct',
                perfdatas => [
                    { value => 'iucast_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        '021_in-bcast'   => { filter => 'add_cast',
            set => {
                key_values => [ { name => 'iucast', diff => 1 }, { name => 'imcast', diff => 1 }, { name => 'ibcast', diff => 1 }, { name => 'display' }, { name => 'mode_cast' } ],
                closure_custom_calc => \&custom_cast_calc, closure_custom_calc_extra_options => { label_ref => 'ibcast', total_ref1 => 'iucast', total_ref2 => 'imcast' },
                output_template => 'In Bcast : %.2f %%', output_error_template => 'In Bcast : %s',
                output_use => 'ibcast_prct',  threshold_use => 'ibcast_prct',
                perfdatas => [
                    { value => 'ibcast_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        '022_in-mcast'   => { filter => 'add_cast',
            set => {
                key_values => [ { name => 'iucast', diff => 1 }, { name => 'imcast', diff => 1 }, { name => 'ibcast', diff => 1 }, { name => 'display' }, { name => 'mode_cast' } ],
                closure_custom_calc => \&custom_cast_calc, closure_custom_calc_extra_options => { label_ref => 'imcast', total_ref1 => 'iucast', total_ref2 => 'ibcast' },
                output_template => 'In Mcast : %.2f %%', output_error_template => 'In Mcast : %s',
                output_use => 'imcast_prct',  threshold_use => 'imcast_prct',
                perfdatas => [
                    { value => 'imcast_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        '023_out-ucast'   => { filter => 'add_cast',
            set => {
                key_values => [ { name => 'oucast', diff => 1 }, { name => 'omcast', diff => 1 }, { name => 'obcast', diff => 1 }, { name => 'display' }, { name => 'mode_cast' } ],
                closure_custom_calc => \&custom_cast_calc, closure_custom_calc_extra_options => { label_ref => 'oucast', total_ref1 => 'omcast', total_ref2 => 'obcast' },
                output_template => 'Out Ucast : %.2f %%', output_error_template => 'Out Ucast : %s',
                output_use => 'oucast_prct',  threshold_use => 'oucast_prct',
                perfdatas => [
                    { value => 'oucast_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        '024_out-bcast'   => { filter => 'add_cast',
            set => {
                key_values => [ { name => 'oucast', diff => 1 }, { name => 'omcast', diff => 1 }, { name => 'obcast', diff => 1 }, { name => 'display' }, { name => 'mode_cast' } ],
                closure_custom_calc => \&custom_cast_calc, closure_custom_calc_extra_options => { label_ref => 'obcast', total_ref1 => 'omcast', total_ref2 => 'oucast' },
                output_template => 'Out Bcast : %.2f %%', output_error_template => 'Out Bcast : %s',
                output_use => 'obcast_prct',  threshold_use => 'obcast_prct',
                perfdatas => [
                    { value => 'obcast_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        '025_out-mcast'   => { filter => 'add_cast',
            set => {
                key_values => [ { name => 'iucast', diff => 1 }, { name => 'imcast', diff => 1 }, { name => 'ibcast', diff => 1 }, { name => 'display' }, { name => 'mode_cast' } ],
                closure_custom_calc => \&custom_cast_calc, closure_custom_calc_extra_options => { label_ref => 'ibcast', total_ref1 => 'iucast', total_ref2 => 'imcast' },
                output_template => 'In Bcast : %.2f %%', output_error_template => 'In Bcast : %s',
                output_use => 'ibcast_prct',  threshold_use => 'ibcast_prct',
                perfdatas => [
                    { value => 'ibcast_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    },
};

#########################
# Calc functions
#########################
sub custom_threshold_output {
    my ($self, %options) = @_; 
    
    my $status = $instance_mode->get_severity(section => 'admin', value => $self->{result_values}->{admstatus});
    if ($self->{output}->is_status(value => $status, compare => 'ok', litteral => 1)) {
        return $status;
    }
    $status = $instance_mode->get_severity(section => 'oper', value => $self->{result_values}->{opstatus});
    return $status;
}

sub custom_status_output {
    my ($self, %options) = @_;
    my $msg = 'Status : ' . $self->{result_values}->{opstatus} . ' (admin status: ' . $self->{result_values}->{admstatus} . ')';
    
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{opstatus} = $options{new_datas}->{$self->{instance} . '_opstatus'};
    $self->{result_values}->{admstatus} = $options{new_datas}->{$self->{instance} . '_admstatus'};
    return 0;
}

sub custom_cast_calc {
    my ($self, %options) = @_;
        
    my $diff_cast = ($options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{label_ref}} - $options{old_datas}->{$self->{instance} . '_' . $options{extra_options}->{label_ref}});
    my $total = $diff_cast
                + ($options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{total_ref1}} - $options{old_datas}->{$self->{instance} . '_' . $options{extra_options}->{total_ref1}}) 
                + ($options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{total_ref2}} - $options{old_datas}->{$self->{instance} . '_' . $options{extra_options}->{total_ref2}});
    if ($options{new_datas}->{$self->{instance} . '_mode_cast'} ne $options{old_datas}->{$self->{instance} . '_mode_cast'}) {
        $self->{error_msg} = "buffer creation";
        return -2;
    }
    if ($total == 0) {
        $self->{error_msg} = "skipped";
        return -2;
    }
    
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{$options{extra_options}->{label_ref} . '_prct'} = $diff_cast * 100 / $total;
    return 0;
}

##############
# Traffic
sub custom_traffic_perfdata {
    my ($self, %options) = @_;
    
    my $extra_label = '';
    if (!defined($options{extra_instance}) || $options{extra_instance} != 0) {
        $extra_label .= '_' . $self->{result_values}->{display};
    }
    my ($warning, $critical);
    if ($instance_mode->{option_results}->{units_traffic} eq '%' && defined($self->{result_values}->{speed})) {
        $warning = $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{label}, total => $self->{result_values}->{speed}, cast_int => 1);
        $critical = $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{label}, total => $self->{result_values}->{speed}, cast_int => 1);
    } elsif ($instance_mode->{option_results}->{units_traffic} eq 'b/s') {
        $warning = $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{label});
        $critical = $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{label});
    }
    $self->{output}->perfdata_add(label => 'traffic_' . $self->{result_values}->{label} . $extra_label, unit => 'b/s',
                                  value => $self->{result_values}->{traffic_per_seconds},
                                  warning => $warning,
                                  critical => $critical,
                                  min => 0, max => $self->{result_values}->{speed});
}

sub custom_traffic_threshold {
    my ($self, %options) = @_;
    
    my $exit = 'ok';
    if ($instance_mode->{option_results}->{units_traffic} eq '%' && defined($self->{result_values}->{speed})) {
        $exit = $self->{perfdata}->threshold_check(value => $self->{result_values}->{traffic_prct}, threshold => [ { label => 'critical-' . $self->{label}, exit_litteral => 'critical' }, { label => 'warning-' . $self->{label}, exit_litteral => 'warning' } ]);
    } elsif ($instance_mode->{option_results}->{units_traffic} eq 'b/s') {
        $exit = $self->{perfdata}->threshold_check(value => $self->{result_values}->{traffic_per_seconds}, threshold => [ { label => 'critical-' . $self->{label}, exit_litteral => 'critical' }, { label => 'warning-' . $self->{label}, exit_litteral => 'warning' } ]);
    }
    return $exit;
}

sub custom_traffic_output {
    my ($self, %options) = @_;
    
    my ($traffic_value, $traffic_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{traffic_per_seconds}, network => 1);    
    my $msg = sprintf("Traffic %s %s/s (%s)",
                      ucfirst($self->{result_values}->{label}), $traffic_value . $traffic_unit,
                      defined($self->{result_values}->{traffic_prct}) ? sprintf("%.2f%%", $self->{result_values}->{traffic_prct}) : '-');
    return $msg;
}

sub custom_traffic_calc {
    my ($self, %options) = @_;

    if ($options{new_datas}->{$self->{instance} . '_mode_traffic'} ne $options{old_datas}->{$self->{instance} . '_mode_traffic'}) {
        $self->{error_msg} = "buffer creation";
        return -2;
    }
    
    my $diff_traffic = ($options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{label_ref}} - $options{old_datas}->{$self->{instance} . '_' . $options{extra_options}->{label_ref}});
    $self->{result_values}->{traffic_per_seconds} = $diff_traffic / $options{delta_time};
    if (defined($options{new_datas}->{$self->{instance} . '_speed_' . $options{extra_options}->{label_ref}}) && 
        $options{new_datas}->{$self->{instance} . '_speed_' . $options{extra_options}->{label_ref}} > 0) {
        $self->{result_values}->{traffic_prct} = $self->{result_values}->{traffic_per_seconds} * 100 / $options{new_datas}->{$self->{instance} . '_speed_' . $options{extra_options}->{label_ref}};
        $self->{result_values}->{speed} = $options{new_datas}->{$self->{instance} . '_speed_' . $options{extra_options}->{label_ref}};
    }
    
    $self->{result_values}->{label} = $options{extra_options}->{label_ref};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}

#########################
# OIDs mapping functions
#########################
sub set_instance {
    my ($self, %options) = @_;
    
    $instance_mode = $self;
}

sub set_oids_label {
    my ($self, %options) = @_;

    $self->{oids_label} = {
        'ifdesc' => '.1.3.6.1.2.1.2.2.1.2',
        'ifalias' => '.1.3.6.1.2.1.31.1.1.1.18',
        'ifname' => '.1.3.6.1.2.1.31.1.1.1.1',
    };
}

sub set_oids_status {
    my ($self, %options) = @_;
    
    $self->{oid_adminstatus} = '.1.3.6.1.2.1.2.2.1.7';
    $self->{oid_adminstatus_mapping} = {
        1 => 'up', 2 => 'down', 3 => 'testing', 4 => 'unknown', 5 => 'dormant', 6 => 'notPresent', 7 => 'lowerLayerDown',
    };
    $self->{oid_opstatus} = '.1.3.6.1.2.1.2.2.1.8';
    $self->{oid_opstatus_mapping} = {
        1 => 'up', 2 => 'down', 3 => 'testing', 4 => 'unknown', 5 => 'dormant', 6 => 'notPresent', 7 => 'lowerLayerDown',
    };
    
    $self->{thresholds_status} = {
        oper => [
            ['up', 'OK'],
            ['.*', 'CRITICAL'],
        ],
        admin => [
            ['down', 'OK'],
        ],
    };
}

sub set_oids_traffic {
    my ($self, %options) = @_;
    
    $self->{oid_speed32} = '.1.3.6.1.2.1.2.2.1.5'; # in b/s
    $self->{oid_in32} = '.1.3.6.1.2.1.2.2.1.10'; # in B
    $self->{oid_out32} = '.1.3.6.1.2.1.2.2.1.16'; # in B
    $self->{oid_speed64} = '.1.3.6.1.2.1.31.1.1.1.15'; # need multiple by '1000000'
    $self->{oid_in64} = '.1.3.6.1.2.1.31.1.1.1.6'; # in B
    $self->{oid_out64} = '.1.3.6.1.2.1.31.1.1.1.10'; # in B
}

sub set_oids_cast {
    my ($self, %options) = @_;
    
    # 32bits
    $self->{oid_ifInUcastPkts} = '.1.3.6.1.2.1.2.2.1.11';
    $self->{oid_ifInBroadcastPkts} = '.1.3.6.1.2.1.31.1.1.1.3';
    $self->{oid_ifInMulticastPkts} = '.1.3.6.1.2.1.31.1.1.1.2';
    $self->{oid_ifOutUcastPkts} = '.1.3.6.1.2.1.2.2.1.17';
    $self->{oid_ifOutMulticastPkts} = '.1.3.6.1.2.1.31.1.1.1.4';
    $self->{oid_ifOutBroadcastPkts} = '.1.3.6.1.2.1.31.1.1.1.5';
    
    # 64 bits
    $self->{oid_ifHCInUcastPkts} = '.1.3.6.1.2.1.31.1.1.1.7';
    $self->{oid_ifHCInMulticastPkts} = '.1.3.6.1.2.1.31.1.1.1.8';
    $self->{oid_ifHCInBroadcastPkts} = '.1.3.6.1.2.1.31.1.1.1.9';
    $self->{oid_ifHCOutUcastPkts} = '.1.3.6.1.2.1.31.1.1.1.11';
    $self->{oid_ifHCOutMulticastPkts} = '.1.3.6.1.2.1.31.1.1.1.12';
    $self->{oid_ifHCOutBroadcastPkts} = '.1.3.6.1.2.1.31.1.1.1.13';
}

sub check_oids_label {
    my ($self, %options) = @_;
    
    $self->{option_results}->{oid_filter} = lc($self->{option_results}->{oid_filter});
    foreach (('oid_filter', 'oid_display')) {
        if (!defined($self->{oids_label}->{lc($self->{option_results}->{$_})})) {
            my $label = $_;
            $label =~ s/_/-/g;
            $self->{output}->add_option_msg(short_msg => "Unsupported --" . $label . " option.");
            $self->{output}->option_exit();
        }
    }
}

sub default_oid_filter_name {
    my ($self, %options) = @_;
    
    return 'ifname';
}

sub default_oid_display_name {
    my ($self, %options) = @_;
    
    return 'ifname';
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                "add-status"              => { name => 'add_status' },
                                "add-traffic"             => { name => 'add_traffic' },
                                "add-errors"              => { name => 'add_errors' },
                                "add-cast"                => { name => 'add_cast' },
                                "oid-filter:s"            => { name => 'oid_filter', default => $self->default_oid_filter_name() },
                                "oid-display:s"           => { name => 'oid_display', default => $self->default_oid_display_name() },
                                "interface:s"             => { name => 'interface' },
                                "name"                    => { name => 'use_name' },
                                "units-traffic:s"         => { name => 'units_traffic', default => '%' },
                                "speed:s"                 => { name => 'speed' },
                                "speed-in:s"              => { name => 'speed_in' },
                                "speed-out:s"             => { name => 'speed_out' },
                                "display-transform-src:s" => { name => 'display_transform_src' },
                                "display-transform-dst:s" => { name => 'display_transform_dst' },
                                "show-cache"              => { name => 'show_cache' },
                                "reload-cache-time:s"     => { name => 'reload_cache_time', default => 180 },
                                "threshold-overload:s@"   => { name => 'threshold_overload' },
                                }); 
    $self->{statefile_value} = centreon::plugins::statefile->new(%options);
    $self->{statefile_cache} = centreon::plugins::statefile->new(%options);

    foreach my $key (('int')) {
        foreach (keys %{$maps_counters->{$key}}) {
            my ($id, $name) = split /_/;
            if (!defined($maps_counters->{$key}->{$_}->{threshold}) || $maps_counters->{$key}->{$_}->{threshold} != 0) {
                $options{options}->add_options(arguments => {
                                                    'warning-' . $name . ':s'    => { name => 'warning-' . $name },
                                                    'critical-' . $name . ':s'    => { name => 'critical-' . $name },
                                               });
            }
            $maps_counters->{$key}->{$_}->{obj} = centreon::plugins::values->new(statefile => $self->{statefile_value},
                                                      output => $self->{output}, perfdata => $self->{perfdata},
                                                      label => $name);
            $maps_counters->{$key}->{$_}->{obj}->set(%{$maps_counters->{$key}->{$_}->{set}});
        }
    }
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    foreach my $key (('int')) {
        foreach (keys %{$maps_counters->{$key}}) {
            $maps_counters->{$key}->{$_}->{obj}->init(option_results => $self->{option_results});
        }
    }
    
    $self->set_oids_label();
    $self->check_oids_label();
    
    $self->set_instance();
    $self->{statefile_cache}->check_options(%options);
    $self->{statefile_value}->check_options(%options);
    
    if (defined($self->{option_results}->{add_traffic}) && 
        (!defined($self->{option_results}->{units_traffic}) || $self->{option_results}->{units_traffic} !~ /^(%|b\/s)$/)) {
        $self->{output}->add_option_msg(short_msg => "Wrong option --units-traffic.");
        $self->{output}->option_exit();
    }
    
    if ((!defined($self->{option_results}->{speed}) || $self->{option_results}->{speed} eq '') &&
        ((!defined($self->{option_results}->{speed_in}) || $self->{option_results}->{speed_in} eq '') ||
        (!defined($self->{option_results}->{speed_out}) || $self->{option_results}->{speed_out} eq ''))) {
        $self->{get_speed} = 1;
    }
    
    # If no options, we set status
    if (!defined($self->{option_results}->{add_status}) && !defined($self->{option_results}->{add_traffic}) &&
        !defined($self->{option_results}->{add_errors}) && !defined($self->{option_results}->{add_cast})) {
        $self->{option_results}->{add_status} = 1;
    }
    $self->{checking} = '';
    foreach (('add_status', 'add_errors', 'add_traffic', 'add_cast')) {
        if (defined($self->{options_results}->{$_})) {
            $self->{checking} .= $_;
        }
    }
    
    $self->{overload_th} = {};
    foreach my $val (@{$self->{option_results}->{threshold_overload}}) {
        if ($val !~ /^(.*?),(.*?),(.*)$/) {
            $self->{output}->add_option_msg(short_msg => "Wrong threshold-overload option '" . $val . "'.");
            $self->{output}->option_exit();
        }
        my ($section, $status, $filter) = ($1, $2, $3);
        if ($self->{output}->is_litteral_status(status => $status) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong threshold-overload status '" . $val . "'.");
            $self->{output}->option_exit();
        }
        $self->{overload_th}->{$section} = [] if (!defined($self->{overload_th}->{$section}));
        push @{$self->{overload_th}->{$section}}, {filter => $filter, status => $status};
    }
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    $self->{hostname} = $self->{snmp}->get_hostname();
    $self->{snmp_port} = $self->{snmp}->get_port();
    
    $self->get_informations();
    
    my $multiple = 1;
    if (scalar(keys %{$self->{int}}) == 1) {
        $multiple = 0;
    }
    
    if ($multiple == 1) {
        $self->{output}->output_add(severity => 'OK',
                                    short_msg => 'All interfaces are ok');
    }
    
    $self->{new_datas} = {};
    $self->{statefile_value}->read(statefile => "snmpstandard_" . $self->{hostname}  . '_' . $self->{snmp_port} . '_' . $self->{mode} . '_' . 
            (defined($self->{option_results}->{interface}) ? md5_hex($self->{option_results}->{interface}) : md5_hex('all')) . '_' .
             md5_hex($self->{checking}));
    $self->{new_datas}->{last_timestamp} = time();
    
    foreach my $id (sort keys %{$self->{interface_selected}}) {     
        my ($short_msg, $short_msg_append, $long_msg, $long_msg_append) = ('', '', '', '');
        my @exits = ();
        foreach (sort keys %{$maps_counters->{int}}) {
            my $obj = $maps_counters->{int}->{$_}->{obj};
            next if (!defined($self->{option_results}->{$maps_counters->{int}->{$_}->{filter}}));
            $obj->set(instance => $id);
        
            my ($value_check) = $obj->execute(values => $self->{interface_selected}->{$id},
                                              new_datas => $self->{new_datas});

            if ($value_check != 0) {
                $long_msg .= $long_msg_append . $obj->output_error();
                $long_msg_append = ', ';
                next;
            }
            my $exit2 = $obj->threshold_check();
            push @exits, $exit2;

            my $output = $obj->output();
            $long_msg .= $long_msg_append . $output;
            $long_msg_append = ', ';
            
            if (!$self->{output}->is_status(litteral => 1, value => $exit2, compare => 'ok')) {
                $short_msg .= $short_msg_append . $output;
                $short_msg_append = ', ';
            }
            
            $maps_counters->{int}->{$_}->{obj}->perfdata(extra_instance => $multiple);
        }

        $self->{output}->output_add(long_msg => "Interface '" . $self->{interface_selected}->{$id}->{display} . "' $long_msg");
        my $exit = $self->{output}->get_most_critical(status => [ @exits ]);
        if (!$self->{output}->is_status(litteral => 1, value => $exit, compare => 'ok')) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => "Inteface '" . $self->{interface_selected}->{$id}->{display} . "' $short_msg"
                                        );
        }
        
        if ($multiple == 0) {
            $self->{output}->output_add(short_msg => "Interface '" . $self->{interface_selected}->{$id}->{display} . "' $long_msg");
        }
    }
    
    $self->{statefile_value}->write(data => $self->{new_datas});
    $self->{output}->display();
    $self->{output}->exit();
}

sub get_severity {
    my ($self, %options) = @_;
    my $status = 'UNKNOWN'; # default 
    
    if (defined($self->{overload_th}->{$options{section}})) {
        foreach (@{$self->{overload_th}->{$options{section}}}) {            
            if ($options{value} =~ /$_->{filter}/i) {
                $status = $_->{status};
                return $status;
            }
        }
    }
    foreach (@{$self->{thresholds_status}->{$options{section}}}) {           
        if ($options{value} =~ /$$_[0]/i) {
            $status = $$_[1];
            return $status;
        }
    }
    
    return $status;
}

sub get_display_value {
    my ($self, %options) = @_;
    my $value = $self->{statefile_cache}->get(name => $self->{option_results}->{oid_display} . "_" . $options{id});

    if (defined($self->{option_results}->{display_transform_src})) {
        $self->{option_results}->{display_transform_dst} = '' if (!defined($self->{option_results}->{display_transform_dst}));
        eval "\$value =~ s{$self->{option_results}->{display_transform_src}}{$self->{option_results}->{display_transform_dst}}";
    }
    return $value;
}
sub reload_cache {
    my ($self) = @_;
    my $datas = {};

    $datas->{oid_filter} = $self->{option_results}->{oid_filter};
    $datas->{oid_display} = $self->{option_results}->{oid_display};
    $datas->{last_timestamp} = time();
    $datas->{all_ids} = [];
    
    my $snmp_get = [
        { oid => $self->{oids_label}->{$self->{option_results}->{oid_filter}} },
    ];
    if ($self->{option_results}->{oid_filter} ne $self->{option_results}->{oid_display}) {
        push @{$snmp_get}, { oid => $self->{oids_label}->{$self->{option_results}->{oid_display}} };
    }
    
    my $result = $self->{snmp}->get_multiple_table(oids => $snmp_get);
    foreach ($self->{snmp}->oid_lex_sort(keys %{$result->{$self->{oids_label}->{$self->{option_results}->{oid_filter}}}})) {
        /\.([0-9]+)$/;
        push @{$datas->{all_ids}}, $1;
        $datas->{$self->{option_results}->{oid_filter} . "_" . $1} = $self->{output}->to_utf8($result->{$self->{oids_label}->{$self->{option_results}->{oid_filter}}}->{$_});
    }

    if (scalar(@{$datas->{all_ids}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "Can't construct cache...");
        $self->{output}->option_exit();
    }

    if ($self->{option_results}->{oid_filter} ne $self->{option_results}->{oid_display}) {
       foreach ($self->{snmp}->oid_lex_sort(keys %{$result->{$self->{oids_label}->{$self->{option_results}->{oid_display}}}})) {
            /\.([0-9]+)$/;
            $datas->{$self->{option_results}->{oid_display} . "_" . $1} = $self->{output}->to_utf8($result->{$self->{oids_label}->{$self->{option_results}->{oid_display}}}->{$_});
       }
    }
    
    $self->{statefile_cache}->write(data => $datas);
}

sub get_selection {
    my ($self, %options) = @_;
    
    # init cache file
    my $has_cache_file = $self->{statefile_cache}->read(statefile => 'cache_snmpstandard_' . $self->{hostname}  . '_' . $self->{snmp_port} . '_' . $self->{mode});
    if (defined($self->{option_results}->{show_cache})) {
        $self->{output}->add_option_msg(long_msg => $self->{statefile_cache}->get_string_content());
        $self->{output}->option_exit();
    }

    $self->{interface_selected} = {};
    my $timestamp_cache = $self->{statefile_cache}->get(name => 'last_timestamp');
    my $oid_display = $self->{statefile_cache}->get(name => 'oid_display');
    my $oid_filter = $self->{statefile_cache}->get(name => 'oid_filter');
    if ($has_cache_file == 0 ||
        ($self->{option_results}->{oid_display} !~ /^($oid_display|$oid_filter)$/i || $self->{option_results}->{oid_filter} !~ /^($oid_display|$oid_filter)$/i) ||
        !defined($timestamp_cache) || ((time() - $timestamp_cache) > (($self->{option_results}->{reload_cache_time}) * 60))) {
        $self->reload_cache();
        $self->{statefile_cache}->read();
    }

    my $all_ids = $self->{statefile_cache}->get(name => 'all_ids');
    if (!defined($self->{option_results}->{use_name}) && defined($self->{option_results}->{interface})) {
        foreach (@{$all_ids}) {
            if ($self->{option_results}->{interface} =~ /(^|\s|,)$_(\s*,|$)/) {
                $self->{interface_selected}->{$_} = { display => $self->get_display_value(id => $_) };
            }
        }
    } else {
        foreach (@{$all_ids}) {
            my $filter_name = $self->{statefile_cache}->get(name => $self->{option_results}->{oid_filter} . "_" . $_);
            next if (!defined($filter_name));
            if (!defined($self->{option_results}->{interface})) {
                $self->{interface_selected}->{$_} = { display => $self->get_display_value(id => $_) }; 
                next;
            }
            if ($filter_name =~ /$self->{option_results}->{interface}/) {
                $self->{interface_selected}->{$_} = { display => $self->get_display_value(id => $_) }; 
            }
        }
    }
    
    if (scalar(keys %{$self->{interface_selected}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No entry found (maybe you should reload cache file)");
        $self->{output}->option_exit();
    }
}

sub load_status {
    my ($self, %options) = @_;
    
    $self->set_oids_status();
    $self->{snmp}->load(oids => [$self->{oid_adminstatus}, $self->{oid_opstatus}], instances => $self->{array_interface_selected});
}

sub load_traffic {
    my ($self, %options) = @_;
    
    $self->set_oids_traffic();
    $self->{snmp}->load(oids => [$self->{oid_in32}, $self->{oid_out32}], instances => $self->{array_interface_selected});
    if ($self->{get_speed} == 1) {
        $self->{snmp}->load(oids => [$self->{oid_speed32}], instances => $self->{array_interface_selected});
    }
    if (!$self->{snmp}->is_snmpv1()) {
        $self->{snmp}->load(oids => [$self->{oid_in64}, $self->{oid_out64}], instances => $self->{array_interface_selected});
        if ($self->{get_speed} == 1) {
            $self->{snmp}->load(oids => [$self->{oid_speed64}], instances => $self->{array_interface_selected});
        }
    }
}

sub load_cast {
    my ($self, %options) = @_;

    $self->set_oids_cast();    
    $self->{snmp}->load(oids => [$self->{oid_ifInUcastPkts}, $self->{oid_ifInBroadcastPkts}, $self->{oid_ifInMulticastPkts},
                                 $self->{oid_ifOutUcastPkts}, $self->{oid_ifOutMulticastPkts}, $self->{oid_ifOutBroadcastPkts}],
                        instances => $self->{array_interface_selected});
    if (!$self->{snmp}->is_snmpv1()) {
        $self->{snmp}->load(oids => [$self->{oid_ifHCInUcastPkts}, $self->{oid_ifHCInMulticastPkts}, $self->{oid_ifHCInBroadcastPkts},
                                     $self->{oid_ifHCOutUcastPkts}, $self->{oid_ifHCOutMulticastPkts}, $self->{oid_ifHCOutBroadcastPkts}],
                            instances => $self->{array_interface_selected});
    }
}

sub get_informations {
    my ($self, %options) = @_;

    $self->get_selection();
    $self->{array_interface_selected} = [keys %{$self->{interface_selected}}];    
    $self->load_status() if (defined($self->{option_results}->{add_status}));
    $self->load_traffic() if (defined($self->{option_results}->{add_traffic}));
    $self->load_cast() if (defined($self->{option_results}->{add_cast}));

    $self->{results} = $self->{snmp}->get_leef();
    
    foreach (@{$self->{array_interface_selected}}) {
        $self->add_result_status(instance => $_) if (defined($self->{option_results}->{add_status}));
        $self->add_result_traffic(instance => $_) if (defined($self->{option_results}->{add_traffic}));
        $self->add_result_cast(instance => $_) if (defined($self->{option_results}->{add_cast}));
    }
}

sub add_result_status {
    my ($self, %options) = @_;
    
    $self->{interface_selected}->{$options{instance}}->{opstatus} = $self->{oid_opstatus_mapping}->{$self->{results}->{$self->{oid_opstatus} . '.' . $options{instance}}};
    $self->{interface_selected}->{$options{instance}}->{admstatus} = $self->{oid_adminstatus_mapping}->{$self->{results}->{$self->{oid_adminstatus} . '.' . $options{instance}}};
}

sub add_result_traffic {
    my ($self, %options) = @_;
    
    $self->{interface_selected}->{$options{instance}}->{mode_traffic} = 32;
    $self->{interface_selected}->{$options{instance}}->{in} = $self->{results}->{$self->{oid_in32} . '.' . $options{instance}};
    $self->{interface_selected}->{$options{instance}}->{out} = $self->{results}->{$self->{oid_out32} . '.' . $options{instance}};
    if (!$self->{snmp}->is_snmpv1()) {
        if (defined($self->{results}->{$self->{oid_in64} . '.' . $options{instance}}) && $self->{results}->{$self->{oid_in64} . '.' . $options{instance}} ne '' &&
            $self->{results}->{$self->{oid_in64} . '.' . $options{instance}} != 0) {
            $self->{interface_selected}->{$options{instance}}->{mode_traffic} = 64;
            $self->{interface_selected}->{$options{instance}}->{in} = $self->{results}->{$self->{oid_in64} . '.' . $options{instance}};
            $self->{interface_selected}->{$options{instance}}->{out} = $self->{results}->{$self->{oid_out64} . '.' . $options{instance}};
        }
    }
    $self->{interface_selected}->{$options{instance}}->{in} *= 8;
    $self->{interface_selected}->{$options{instance}}->{out} *= 8;
    
    $self->{interface_selected}->{$options{instance}}->{speed_in} = 0;
    $self->{interface_selected}->{$options{instance}}->{speed_out} = 0;
    if ($self->{get_speed} == 0) {
        if (defined($self->{option_results}->{speed}) && $self->{option_results}->{speed} ne '') {
            $self->{interface_selected}->{$options{instance}}->{speed_in} = $self->{option_results}->{speed} * 1000000;
            $self->{interface_selected}->{$options{instance}}->{speed_out} = $self->{option_results}->{speed} * 1000000;
        }
        $self->{interface_selected}->{$options{instance}}->{speed_in} = $self->{option_results}->{speed_in} * 1000000 if (defined($self->{option_results}->{speed_in}) && $self->{option_results}->{speed_in} ne '');
        $self->{interface_selected}->{$options{instance}}->{speed_out} = $self->{option_results}->{speed_out} * 1000000 if (defined($self->{option_results}->{speed_out}) && $self->{option_results}->{speed_out} ne '');
    } else {
        my $interface_speed = 0;
        if (defined($self->{results}->{$self->{oid_speed64} . "." . $options{instance}}) && $self->{results}->{$self->{oid_speed64} . "." . $options{instance}} ne '') {
            $interface_speed = $self->{results}->{$self->{oid_speed64} . "." . $options{instance}} * 1000000;
            # If 0, we put the 32 bits
            if ($interface_speed == 0) {
                $interface_speed = $self->{results}->{$self->{oid_speed32} . "." . $options{instance}};
            }
        } else {
            $interface_speed = $self->{results}->{$self->{oid_speed32} . "." . $options{instance}};
        }
        
        $self->{interface_selected}->{$options{instance}}->{speed_in} = $interface_speed;
        $self->{interface_selected}->{$options{instance}}->{speed_out} = $interface_speed;
        $self->{interface_selected}->{$options{instance}}->{speed_in} = $self->{option_results}->{speed_in} * 1000000 if (defined($self->{option_results}->{speed_in}) && $self->{option_results}->{speed_in} ne '');
        $self->{interface_selected}->{$options{instance}}->{speed_out} = $self->{option_results}->{speed_out} * 1000000 if (defined($self->{option_results}->{speed_out}) && $self->{option_results}->{speed_out} ne '');
    }
}
    
sub add_result_cast {
    my ($self, %options) = @_;
    
    $self->{interface_selected}->{$options{instance}}->{mode_cast} = 32;
    $self->{interface_selected}->{$options{instance}}->{iucast} = $self->{results}->{$self->{oid_ifInUcastPkts} . '.' . $options{instance}};
    $self->{interface_selected}->{$options{instance}}->{ibcast} = defined($self->{results}->{$self->{oid_ifInBroadcastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifInBroadcastPkts} . '.' . $options{instance}} : 0;
    $self->{interface_selected}->{$options{instance}}->{imcast} = defined($self->{results}->{$self->{oid_ifInMulticastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifInMulticastPkts} . '.' . $options{instance}} : 0;
    $self->{interface_selected}->{$options{instance}}->{oucast} = $self->{results}->{$self->{oid_ifOutUcastPkts} . '.' . $options{instance}};
    $self->{interface_selected}->{$options{instance}}->{omcast} = defined($self->{results}->{$self->{oid_ifOutMulticastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifOutMulticastPkts} . '.' . $options{instance}} : 0;
    $self->{interface_selected}->{$options{instance}}->{obcast} = defined($self->{results}->{$self->{oid_ifOutBroadcastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifOutBroadcastPkts} . '.' . $options{instance}} : 0;
    if (!$self->{snmp}->is_snmpv1()) {
        my $iucast = $self->{results}->{$self->{oid_ifHCInUcastPkts} . '.' . $options{instance}};
        if (defined($iucast) && $iucast =~ /[1-9]/) {
            $self->{interface_selected}->{$options{instance}}->{iucast} = $iucast;
            $self->{interface_selected}->{$options{instance}}->{imcast} = defined($self->{results}->{$self->{oid_ifHCInMulticastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifHCInMulticastPkts} . '.' . $options{instance}} : 0;
            $self->{interface_selected}->{$options{instance}}->{ibcast} = defined($self->{results}->{$self->{oid_ifHCInBroadcastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifHCInBroadcastPkts} . '.' . $options{instance}} : 0;
            $self->{interface_selected}->{$options{instance}}->{oucast} = $self->{results}->{$self->{oid_ifHCOutUcastPkts} . '.' . $options{instance}};
            $self->{interface_selected}->{$options{instance}}->{omcast} = defined($self->{results}->{$self->{oid_ifHCOutMulticastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifHCOutMulticastPkts} . '.' . $options{instance}} : 0;
            $self->{interface_selected}->{$options{instance}}->{obcast} = defined($self->{results}->{$self->{oid_ifHCOutBroadcastPkts} . '.' . $options{instance}}) ? $self->{results}->{$self->{oid_ifHCOutBroadcastPkts} . '.' . $options{instance}} : 0;
            $self->{interface_selected}->{$options{instance}}->{mode_cast} = 64;
        }
    }
}


1;

__END__

=head1 MODE

Check interfaces.

=over 8

=item B<--add-status>

Check interface status (By default if no --add-* option is set).

=item B<--add-traffic>

Check interface traffic.

=item B<--add-cast>

Check interface cast.

=item B<--warning-*>

Threshold warning.
Can be: 'in-ucast' (%), 'in-bcast' (%), 'in-mcast' (%), 'out-ucast' (%), 'out-bcast' (%), 'out-mcast' (%).

=item B<--critical-*>

Threshold critical.
Can be: 'in-ucast' (%), 'in-bcast' (%), 'in-mcast' (%), 'out-ucast' (%), 'out-bcast' (%), 'out-mcast' (%).

=item B<--units-traffic>

Units of thresholds for the traffic (Default: '%') ('%', 'b/s').

=item B<--threshold-overload>

Set to overload default threshold values (syntax: section,status,regexp)
It used before default thresholds (order stays).
How to avoid errors on interface status: --threshold-overload='oper,OK,.*'

=item B<--interface>

Set the interface (number expected) ex: 1,2,... (empty means 'check all interface').

=item B<--name>

Allows to use interface name with option --interface instead of interface oid index (Can be a regexp)

=item B<--speed>

Set interface speed for incoming/outgoing traffic (in Mb).

=item B<--speed-in>

Set interface speed for incoming traffic (in Mb).

=item B<--speed-out>

Set interface speed for outgoing traffic (in Mb).

=item B<--reload-cache-time>

Time in seconds before reloading cache file (default: 180).

=item B<--oid-filter>

Choose OID used to filter interface (default: ifName) (values: ifDesc, ifAlias, ifName).

=item B<--oid-display>

Choose OID used to display interface (default: ifName) (values: ifDesc, ifAlias, ifName).

=item B<--display-transform-src>

Regexp src to transform display value. (security risk!!!)

=item B<--display-transform-dst>

Regexp dst to transform display value. (security risk!!!)

=item B<--show-cache>

Display cache interface datas.

=back

=cut
