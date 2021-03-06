# Class is used to install and configure an Apache Kafka Broker using the Confluent installation packages.
#
# @example Installation through class.
#     class{'confluent::kafka::broker':
#       broker_id => '1',
#       config => {
#         'zookeeper.connect' => {
#           'value' => 'zookeeper-01.custenborder.com:2181,zookeeper-02.custenborder.com:2181,zookeeper-03.custenborder.com:2181'
#         },
#       },
#       environment_settings => {
#         'KAFKA_HEAP_OPTS' => {
#           'value' => '-Xmx4000M'
#         }
#       }
#     }
#
# @example Hiera based installation
#     include ::confluent::kafka::broker
#
#     confluent::kafka::broker::broker_id: '1'
#     confluent::kafka::broker::config:
#       zookeeper.connect:
#         value: 'zookeeper-01.example.com:2181,zookeeper-02.example.com:2181,zookeeper-03.example.com:2181'
#       log.dirs:
#         value: /var/lib/kafka
#       advertised.listeners:
#         value: "PLAINTEXT://%{::fqdn}:9092"
#       delete.topic.enable:
#         value: true
#       auto.create.topics.enable:
#         value: false
#     confluent::kafka::broker::environment_settings:
#       KAFKA_HEAP_OPTS:
#         value: -Xmx1024M
#
# @param broker_id broker.id of the Kafka broker.
# @param config Hash of configuration values.
# @param environment_settings Hash of environment variables to set for the Kafka scripts.
# @param config_path Location of the server.properties file for the Kafka broker.
# @param environment_file Location of the environment file used to pass environment variables to the Kafka broker.
# @param data_path Location to store the data on disk.
# @param log_path Location to write the log files to.
# @param user User to run the kafka service as.
# @param service_name Name of the kafka service.
# @param manage_service Flag to determine if the service should be managed by puppet.
# @param service_ensure Ensure setting to pass to service resource.
# @param service_enable Enable setting to pass to service resource.
# @param file_limit File limit to set for the Kafka service (SystemD) only.
class confluent::kafka::broker (
  $broker_id,
  $config               = { },
  $environment_settings = { },
  $config_path          = $::confluent::params::kafka_config_path,
  $environment_file     = $::confluent::params::kafka_environment_path,
  $data_path            = $::confluent::params::kafka_data_path,
  $log_path             = $::confluent::params::kafka_log_path,
  $user                 = $::confluent::params::kafka_user,
  $service_name         = $::confluent::params::kafka_service,
  $manage_service       = $::confluent::params::kafka_manage_service,
  $service_ensure       = $::confluent::params::kafka_service_ensure,
  $service_enable       = $::confluent::params::kafka_service_enable,
  $file_limit           = $::confluent::params::kafka_file_limit,
) inherits confluent::params {
  include ::confluent::kafka

  validate_hash($config)
  validate_hash($environment_settings)
  validate_absolute_path($config_path)
  validate_absolute_path($log_path)
  validate_absolute_path($config_path)


  $kafka_default_settings = {
    'broker.id' => {
      'value' => $broker_id
    },
    'log.dirs' => {
      'value' => $data_path
    }
  }

  $java_default_settings = {
    'KAFKA_HEAP_OPTS' => {
      'value' => '-Xmx256M'
    },
    'KAFKA_OPTS'      => {
      'value' => '-Djava.net.preferIPv4Stack=true'
    },
    'GC_LOG_ENABLED'  => {
      'value' => 'true'
    },
    'LOG_DIR'         => {
      'value' => '/var/log/kafka'
    }
  }

  $actual_kafka_settings = merge($kafka_default_settings, $config)
  $actual_java_settings = merge($java_default_settings, $environment_settings)

  user { $user:
    ensure => present
  } ->
    file { [$log_path, $data_path]:
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true
    }

  $ensure_kafka_settings_defaults = {
    'ensure'      => 'present',
    'path'        => $config_path,
    'application' => 'kafka'
  }

  ensure_resources('confluent::java_property', $actual_kafka_settings, $ensure_kafka_settings_defaults)

  $ensure_java_settings_defaults = {
    'path'        => $environment_file,
    'application' => 'kafka'
  }

  ensure_resources('confluent::kafka_environment_variable', $actual_java_settings, $ensure_java_settings_defaults)

  $unit_ini_setting_defaults = {
    'ensure' => 'present'
  }

  $unit_ini_settings = {
    'kafka/Unit/Description'        => { 'value' => 'Apache Kafka by Confluent', },
    'kafka/Unit/Wants'              => { 'value' => 'basic.target', },
    'kafka/Unit/After'              => { 'value' => 'basic.target network.target', },
    'kafka/Service/User'            => { 'value' => $user, },
    'kafka/Service/EnvironmentFile' => { 'value' => $environment_file, },
    'kafka/Service/ExecStart'       => { 'value' => "/usr/bin/kafka-server-start ${config_path}", },
    'kafka/Service/ExecStop'        => { 'value' => "/usr/bin/kafka-server-stop", },
    'kafka/Service/LimitNOFILE'     => { 'value' => $file_limit, },
    'kafka/Service/KillMode'        => { 'value' => 'process', },
    'kafka/Service/RestartSec'      => { 'value' => 5, },
    'kafka/Service/Type'            => { 'value' => 'simple', },
    'kafka/Install/WantedBy'        => { 'value' => 'multi-user.target', },
  }

  ensure_resources('confluent::systemd::unit_ini_setting', $unit_ini_settings, $unit_ini_setting_defaults)

  if($manage_service) {
    service { $service_name:
      ensure => $service_ensure,
      enable => $service_enable
    }
  }
}