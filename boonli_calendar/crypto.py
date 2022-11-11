"""Encryption and decryption tools using Google Cloud KMS.

See: https://cloud.google.com/kms/docs/samples
"""
import os
from typing import Dict

import crcmod
import six
from google.cloud import kms


def _get_config() -> Dict[str, str]:
    config = {}
    for key in ["PROJECT_NAME", "KEY_RING_LOCATION", "KEY_RING_NAME", "KEY_NAME"]:
        config[key] = os.environ[key]

    return config


def crc32c(data: bytes) -> int:
    """Calculates the CRC32C checksum of the provided data.

    Args:
        data: the bytes over which the checksum should be calculated.

    Returns:
        An int representing the CRC32C checksum of the provided bytes.
    """

    crc32c_fun = crcmod.predefined.mkPredefinedCrcFun("crc-32c")
    return crc32c_fun(six.ensure_binary(data))


def encrypt_symmetric(plaintext: str) -> bytes:
    """Encrypt plaintext using a symmetric key.

    Args:
        plaintext (string): message to encrypt

    Returns:
        bytes: Encrypted ciphertext.
    """

    config = _get_config()

    plaintext_bytes = plaintext.encode("utf-8")
    plaintext_crc32c = crc32c(plaintext_bytes)
    client = kms.KeyManagementServiceClient()
    key_name = client.crypto_key_path(
        config["PROJECT_NAME"],
        config["KEY_RING_LOCATION"],
        config["KEY_RING_NAME"],
        config["KEY_NAME"],
    )

    # Call the API.
    encrypt_response = client.encrypt(
        request={
            "name": key_name,
            "plaintext": plaintext_bytes,
            "plaintext_crc32c": plaintext_crc32c,
        }
    )
    ciphertext: bytes = encrypt_response.ciphertext  # type: ignore

    # For more details on ensuring E2E in-transit integrity to and from Cloud KMS visit:
    # https://cloud.google.com/kms/docs/data-integrity-guidelines
    if not encrypt_response.verified_plaintext_crc32c:
        raise Exception("The request sent to the server was corrupted in-transit.")
    if not encrypt_response.ciphertext_crc32c == crc32c(ciphertext):
        raise Exception("The response received from the server was corrupted in-transit.")
    # End integrity verification

    return ciphertext


def decrypt_symmetric(ciphertext: bytes) -> str:
    """Decrypt the ciphertext using the symmetric key.

    Args:
        ciphertext (bytes): Encrypted bytes to decrypt.

    Returns:
        DecryptResponse: Response including plaintext.
    """
    config = _get_config()

    client = kms.KeyManagementServiceClient()

    key_name = client.crypto_key_path(
        config["PROJECT_NAME"],
        config["KEY_RING_LOCATION"],
        config["KEY_RING_NAME"],
        config["KEY_NAME"],
    )

    ciphertext_crc32c = crc32c(ciphertext)
    request = {"name": key_name, "ciphertext": ciphertext, "ciphertext_crc32c": ciphertext_crc32c}
    decrypt_response = client.decrypt(request=request)
    plaintext: bytes = decrypt_response.plaintext  # type: ignore

    # For more details on ensuring E2E in-transit integrity to and from Cloud KMS visit:
    # https://cloud.google.com/kms/docs/data-integrity-guidelines
    if not decrypt_response.plaintext_crc32c == crc32c(plaintext):
        raise Exception("The response received from the server was corrupted in-transit.")

    return plaintext.decode("utf-8")
