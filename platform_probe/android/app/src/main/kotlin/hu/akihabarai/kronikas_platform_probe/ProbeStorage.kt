package hu.akihabarai.kronikas_platform_probe

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal object ProbeStorage {
    private const val alias = "kronikas-platform-probe-v1"
    private const val ivSize = 12
    private const val tagBits = 128

    fun protect(bytes: ByteArray): ByteArray {
        require(bytes.isNotEmpty() && bytes.size <= 4096)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val key = loadKey() ?: KeyGenerator
            .getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply {
                init(KeyGenParameterSpec.Builder(
                    alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build())
            }.generateKey()
        cipher.init(Cipher.ENCRYPT_MODE, key)
        check(cipher.iv.size == ivSize)
        return cipher.iv + cipher.doFinal(bytes)
    }

    fun unprotect(bytes: ByteArray): ByteArray {
        require(bytes.size in (ivSize + tagBits / 8 + 1)..(4096 + ivSize + tagBits / 8))
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE, checkNotNull(loadKey()),
            GCMParameterSpec(tagBits, bytes, 0, ivSize),
        )
        return cipher.doFinal(bytes, ivSize, bytes.size - ivSize)
    }

    private fun loadKey(): SecretKey? =
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            .getKey(alias, null) as SecretKey?
}
