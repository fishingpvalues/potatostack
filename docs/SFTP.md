● Good choice — nothing to change on the server. On your Windows PC:
                                                                                                                   
  Step 1: Install                                                                                                  
  - WinFsp (filesystem driver)                                                                                     
  - SSHFS-Win (SFTP mount)                                                                                         
                                                                                                                   
  Step 2: Map network drive                                                                                        
  1. Right-click This PC → Map network drive
  2. Pick a drive letter (e.g., S:)                                                                                
  3. Folder: \\sshfs\daniel@100.90.148.77\mnt\storage                                                              
  4. Check Reconnect at sign-in                                                                                    
  5. Check Connect using different credentials
  6. Enter your Linux password for daniel

  Other shares:
  - \\sshfs\daniel@100.90.148.77\mnt\cachehdd
  - \\sshfs\daniel@100.90.148.77\mnt\storage\media
