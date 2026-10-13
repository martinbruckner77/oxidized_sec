# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/oxidized/secure_credentials'

class SecureCredentialsTest < Minitest::Test
  def with_key
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'key')
      File.binwrite(file, OpenSSL::Random.random_bytes(32))
      File.chmod(0o600, file)
      original = ENV['OXIDIZED_CREDENTIAL_KEY_FILE']
      ENV['OXIDIZED_CREDENTIAL_KEY_FILE'] = file
      yield(file)
    ensure
      ENV['OXIDIZED_CREDENTIAL_KEY_FILE'] = original
    end
  end

  def test_round_trip_and_random_nonces
    with_key do
      a = Oxidized::SecureCredentials.encrypt('sample-password')
      b = Oxidized::SecureCredentials.encrypt('sample-password')
      refute_equal a, b
      assert_equal 'sample-password', Oxidized::SecureCredentials.decrypt!(a)
    end
  end

  def test_plaintext_rejected
    with_key do
      assert_raises(Oxidized::SecureCredentials::CredentialError) do
        Oxidized::SecureCredentials.decrypt!('sample-password')
      end
    end
  end

  def test_tampering_rejected
    with_key do
      token = Oxidized::SecureCredentials.encrypt('sample-password')
      bytes = Base64.strict_decode64(token.delete_prefix('enc:v1:'))
      bytes.setbyte(28, bytes.getbyte(28) ^ 1)
      corrupt = 'enc:v1:' + Base64.strict_encode64(bytes)
      assert_raises(Oxidized::SecureCredentials::CredentialError) do
        Oxidized::SecureCredentials.decrypt!(corrupt)
      end
    end
  end

  def test_insecure_key_permissions_rejected
    with_key do |file|
      File.chmod(0o644, file)
      assert_raises(Oxidized::SecureCredentials::CredentialError) do
        Oxidized::SecureCredentials.encrypt('sample')
      end
    end
  end
end
