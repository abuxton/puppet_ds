require 'puppet/resource_api/simple_provider'
require 'puppet/util/puppet_ds/connection'

# Implementation for the puppet_ds type using the Resource API.
class Puppet::Provider::PuppetDs::PuppetDs < Puppet::ResourceApi::SimpleProvider
  def get(context)
    connection     = Puppet::Util::PuppetDs::Connection.new(context)
    current_config = connection.config
    return [] if current_config.empty?

    # Add puppet-specific stuff
    current_config['ensure'] = 'present'
    current_config['name']   = connection.url
    current_config = keys_to_sym(current_config)

    # Wrap the password if it's there
    if current_config[:password]
      current_config[:password] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(current_config[:password])
    end

    [current_config]
  end

  def create(context, name, should)
    connection = Puppet::Util::PuppetDs::Connection.new(context)
    force      = should[:force]
    data       = sanitize_should(should)

    unless force
      context.debug("Validating config for #{name}")
      # This will throw an exception of validation fails
      connection.validate(data)
    end

    connection.config = data # rubocop:disable Lint/UselessSetterCall
  end

  def update(context, name, should)
    create(context, name, should)
  end

  def delete(context, _name)
    connection = Puppet::Util::PuppetDs::Connection.new(context)
    connection.config = {} # rubocop:disable Lint/UselessSetterCall
  end

  private

  def sanitize_should(should)
    # Delete puppet-only keys
    should.delete(:name)
    should.delete(:ensure)
    should.delete(:force)

    # Unwrap the password if it's there
    if should[:password].is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
      should[:password] = should[:password].unwrap
    end

    # Add optional keys as the API requires it. But only if they aren't nil
    should[:group_rdn] ||= nil
    should[:help_link] ||= nil
    should[:login]     ||= nil
    should[:password]  ||= nil
    should[:user_rdn]  ||= nil

    keys_to_strings(should)
  end

  def keys_to_strings(hash)
    hash.map { |k, v| [k.to_s, v] }.to_h
  end

  def keys_to_sym(hash)
    hash.map { |k, v| [k.to_sym, v] }.to_h
  end
end
