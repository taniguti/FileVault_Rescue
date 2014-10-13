FileVault_Rescue
================
This is a helper script when you have to decrypt File Vault with FileVaultMaster.keychain.
There is a document from Apple about what you have to do.

http://support.apple.com/kb/HT5077

But this document describes only unlock volume. If you want to decrypt File vaulted startup disk completely, this script will help you.

Condition:
	- You must be a Mac Administrator of your organization.
	- Managed Mac computer must be file vaulted with your FileVault Master.keychain.
	- Of course you have to know unlock passcode of  FileVault Master.keychain.

Preparation:
	Save this script with your FileVault Master.keychain which must have private key.
	Save unlock passcode of FileVault Master.keychain in the file named "pass.txt".
	Keep it in safe.
	
Video: 
 http://youtu.be/U8GM4pbG0Qg

Validation:
	OS X 10.10GM (14A379a)
	OS X 10.9.5 (13F34)