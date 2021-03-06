FileVault_Rescue
===
This is a helper script when you have to decrypt File Vault with FileVaultMaster.keychain.
There is a document from Apple about what you have to do.

[OS X: How to create and deploy a recovery key for FileVault 2](http://support.apple.com/kb/HT5077)

But this document describes only unlock volume. If you want to decrypt File vaulted startup disk completely, this script will help you.

Condition:
---
* You must be a Mac Administrator of your organization.
* Managed Mac computer must be file vaulted with your FileVault Master.keychain.
* Of course you have to know unlock passcode of  FileVault Master.keychain.

Preparation:
---
1. Save this script with your FileVault Master.keychain which must have private key in it.
2. Save unlock passcode of FileVault Master.keychain in the file named "pass.txt". It must be a plain text file.
3. Keep them in safe.

Tested OS Versions:
---
See [tested_os_version.txt](https://github.com/taniguti/FileVault_Rescue/blob/master/tested_os_version.txt)

Demo Video:
---
<http://youtu.be/U8GM4pbG0Qg>
