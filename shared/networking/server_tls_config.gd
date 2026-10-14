class_name ServerTLSConfig
extends RefCounted

const LOCAL_WSS_FLAG := "--server-local-wss"
const CERT_PREFIX := "--server-tls-cert="
const KEY_PREFIX := "--server-tls-key="


static func from_arguments(arguments: PackedStringArray) -> Dictionary:
	var config := {
		"error": OK,
		"enabled": false,
		"bind_address": "127.0.0.1",
		"tls_options": null,
	}
	var cert_path := ""
	var key_path := ""
	var has_tls_parameters := false
	for argument: String in arguments:
		if argument == LOCAL_WSS_FLAG:
			config["enabled"] = true
		elif argument.begins_with(CERT_PREFIX):
			has_tls_parameters = true
			cert_path = argument.substr(CERT_PREFIX.length())
		elif argument.begins_with(KEY_PREFIX):
			has_tls_parameters = true
			key_path = argument.substr(KEY_PREFIX.length())

	if not config["enabled"]:
		if has_tls_parameters:
			config["error"] = ERR_INVALID_PARAMETER
			push_error("TLS paths require --server-local-wss.")
		return config

	if cert_path.is_empty() or key_path.is_empty():
		config["error"] = ERR_INVALID_PARAMETER
		push_error("Local WSS requires a certificate and a private key.")
		return config

	var certificate := X509Certificate.new()
	var error: Error = certificate.load(cert_path)
	if error != OK:
		config["error"] = error
		push_error("Could not load the local WSS certificate. Error: %s" % error)
		return config

	var key := CryptoKey.new()
	error = key.load(key_path)
	if error != OK:
		config["error"] = error
		push_error("Could not load the local WSS private key. Error: %s" % error)
		return config

	config["tls_options"] = TLSOptions.server(key, certificate)
	return config
