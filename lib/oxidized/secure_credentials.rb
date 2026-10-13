# frozen_string_literal: true

require 'openssl'
require 'base64'

module Oxidized
  # Encrypted device credentials. The key must never be stored in the repository.
  module SecureCredentials
    PREFIX = 'enc:v1:'
    AAD = 'oxidized-credential-v1'

    class CredentialError < StandardError; end

    def self.key
      path = ENV['OXIDIZED_CREDENTIAL_KEY_FILE']
      raise CredentialError, 'OXIDIZED_CREDENTIAL_KEY_FILE must be set' if path.nil? || path.empty?
      stat = File.lstat(path)
      raise CredentialError, 'key must be a regular file, not a symlink' unless stat.file? && !stat.symlink?
      raise CredentialError, 'key permissions must be 0600 or stricter' unless (stat.mode & 0o077).zero?
      raise CredentialError, 'key owner must match running process' unless stat.uid == Process.euid
      bytes = File.binread(path)
      raise CredentialError, 'AES-256 key must be exactly 32 bytes' unless bytes.bytesize == 32
      bytes
    rescue Errno::ENOENT, Errno::EACCES => e
      raise CredentialError, "key file unavailable: #{e.class}"
    end

    def self.encrypt(plaintext)
      raise CredentialError, 'credential must be nonempty text' unless plaintext.is_a?(String) && !plaintext.empty?
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.encrypt
      cipher.key = key
      nonce = OpenSSL::Random.random_bytes(12)
      cipher.iv = nonce
      cipher.auth_data = AAD
      ciphertext = cipher.update(plaintext) + cipher.final
      PREFIX + Base64.strict_encode64(nonce + cipher.auth_tag + ciphertext)
    end

    def self.decrypt!(token)
      raise CredentialError, 'unencrypted credential rejected' unless token.is_a?(String) && token.start_with?(PREFIX)
      raw = Base64.strict_decode64(token.delete_prefix(PREFIX))
      raise CredentialError, 'invalid encrypted credential' if raw.bytesize < 29
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key = key
      cipher.iv = raw.byteslice(0, 12)
      cipher.auth_tag = raw.byteslice(12, 16)
      cipher.auth_data = AAD
      cipher.update(raw.byteslice(28..-1)) + cipher.final
    rescue OpenSSL::Cipher::CipherError, ArgumentError
      raise CredentialError, 'credential cannot be decrypted (invalid key or token)'
    end
  end
end
