# Class is used to install
#
# @example Installation through class.
#     class{'confluent::kafka::connect::distributed':
#       config => {
#         'bootstrap.servers' => {
#           'value' => 'broker-01:9092,broker-02:9092,broker-03:9092'
#         },
#         'key.converter' => {
#           'value' => 'io.confluent.connect.avro.AvroConverter'
#         },
#         'value.converter' => {
#           'value' => 'io.confluent.connect.avro.AvroConverter'
#         },
#         'key.converter.schema.registry.url' => {
#           'value' => 'http://schema-registry-01:8081'
#         },
#         'value.converter.schema.registry.url' => {
#           'value' => 'http://schema-registry-01:8081'
#         },
#       },
#       java_settings => {
#         'KAFKA_HEAP_OPTS' => {
#           'value' => '-Xmx4000M'
#         }
#       }
#     }
#
# @example Hiera based installation
#     include ::confluent::kafka::connect::distributed
#
#      confluent::kafka::connect::distributed::config:
#        'bootstrap.servers':
#          value: 'broker-01:9092,broker-02:9092,broker-03:9092'
#        'key.converter':
#          value: 'io.confluent.connect.avro.AvroConverter'
#        'value.converter':
#          value: 'io.confluent.connect.avro.AvroConverter'
#        'key.converter.schema.registry.url':
#          value: 'http://schema-registry-01.example.com:8081'
#        'value.converter.schema.registry.url':
#          value: 'http://schema-registry-01.example.com:8081'
#      confluent::kafka::connect::distributed::connect_settings:java_settings:
#        KAFKA_HEAP_OPTS:
#          value: '-Xmx4000M'
#
# @param config Settings to pass to the Kafka Connect properties file.
# @param environment_settings Settings to put in the environment file used to pass environment variables to the kafka startup scripts.
# @param config_path Path to the connect properties file.
# @param environment_file The file used to export environment variables that are consumed by Kafka scripts.
# @param log_path The directory to write log files to.
# @param user The user to run Kafka Connect as.
# @param service_name The name of the service to create
# @param manage_service Flag to determine if the service should be enabled.
# @param service_ensure Ensure setting to pass to the service resource.
# @param service_enable Enable setting to pass to the service resource.
# @param file_limit Number of file handles to configure. (SystemD only)
class confluent::kafka::connect::distributed (
  $config               = { },
  $environment_settings = { },
  $config_path          = $::confluent::params::connect_distributed_config_path,
  $environment_file     = $::confluent::params::connect_distributed_environment_path,
  $log_path             = $::confluent::params::connect_distributed_log_path,
  $user                 = $::confluent::params::connect_distributed_user,
  $service_name         = $::confluent::params::connect_distributed_service,
  $manage_service       = $::confluent::params::connect_distributed_manage_service,
  $service_ensure       = $::confluent::params::connect_distributed_service_ensure,
  $service_enable       = $::confluent::params::connect_distributed_service_enable,
  $file_limit           = $::confluent::params::connect_distributed_file_limit,
) inherits ::confluent::params {

  include ::confluent::kafka::connect

  user { $user:
    ensure => present,
    alias  => 'kafka-connect-distributed'
  } ->
    file { $log_path:
      ensure  => directory,
      owner   => $user,
      group   => $user,
      recurse => true
    }

  $application = 'connect-distributed'


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

  $connect_default_settings = {

  }

  $actual_connect_settings = merge($connect_default_settings, $config)

  $ensure_connect_settings_defaults = {
    'ensure'      => 'present',
    'path'        => $config_path,
    'application' => $application
  }

  ensure_resources('confluent::java_property', $actual_connect_settings, $ensure_connect_settings_defaults)

  $actual_java_settings = merge($java_default_settings, $environment_settings)
  $ensure_java_settings_defaults = {
    'path'        => $environment_file,
    'application' => $application
  }

  ensure_resources('confluent::kafka_environment_variable', $actual_java_settings, $ensure_java_settings_defaults)

  $unit_ini_setting_defaults = {
    'ensure' => 'present'
  }

  $unit_ini_settings = {
    'kafka-connect-distributed/Unit/Description'        => { 'value' => 'Apache Kafka Connect by Confluent', },
    'kafka-connect-distributed/Unit/Wants'              => { 'value' => 'basic.target', },
    'kafka-connect-distributed/Unit/After'              => { 'value' => 'basic.target network.target', },
    'kafka-connect-distributed/Service/User'            => { 'value' => $user, },
    'kafka-connect-distributed/Service/EnvironmentFile' => { 'value' => $environment_file, },
    'kafka-connect-distributed/Service/ExecStart'       => {
      'value' => "/usr/bin/connect-distributed ${config_path}",
    },
    'kafka-connect-distributed/Service/LimitNOFILE'     => { 'value' => $file_limit, },
    'kafka-connect-distributed/Service/KillMode'        => { 'value' => 'process', },
    'kafka-connect-distributed/Service/RestartSec'      => { 'value' => 5, },
    'kafka-connect-distributed/Service/Type'            => { 'value' => 'simple', },
    'kafka-connect-distributed/Install/WantedBy'        => { 'value' => 'multi-user.target', },
  }

  ensure_resources('confluent::systemd::unit_ini_setting', $unit_ini_settings, $unit_ini_setting_defaults)

  if($manage_service) {
    service { $service_name:
      ensure => $service_ensure,
      enable => $service_enable
    }
  }

}