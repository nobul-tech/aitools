CVLOG Stats Defined 


 Stat Meaning 
1.  Date Date (Month/Day) 
2.  Time Time (24 hour clock) 
3.  FSM memory Memory used by the FSM's various buffers 
4.  FSM writes total Number of writes the FSM has done 
5.  FSM writes journal Number of writes to the journal 
6.  FSM writes sb Number of writes to the super block 
7.  FSM writes buf Number of s ynchronous writes to metadata 
8.  FSM writes abm Number of writes to the allocation bit map 
9.  FSM writes inode Number of writes of inodes 
10.  FSM writes ganged Number of inode writes th at were able to be concatenated to 
improve efficiency 
11.  FSM inode pool expand waits Number of times the FSM had to wait to expand the inode pool 
12.  FSM journal waits Number of times the FSM had to wait to write to the journal 
13.  FSM journal bytes used avg Averag e number of bytes in the journal 
14.  FSM journal bytes used max Maximu m number of bytes in the journal 
15.  FSM free buffer waits Number of times the FSM had to wait to get a free buffer 
16.  FSM free inode waits Number of times the FSM had to wait to get a free inode 
17.  FSM wait revokes Number of times the FSM  had to wait to switch a file from 
exclusive to shared access 
18.  FSM wait avg Revoke wait time divided by the number of FSM wait revokes  
19.  FSM wait min The shortest wait for a revoke 
20.  FSM wait max The longest wait for a revoke 
21.  FSM threads max busy hi-prio Maximum numbe r of threads working on operations except 
open and lookup 
22.  FSM threads max busy lo-prio Maximum number of threads working on open and lookup 
23.  FSM threads max busy dmig Maximum numbe r of threads working on data migration 
24.  FSM threads max busy events Maximum number of  threads working on data migration events 
25.  FSM msg queue hi-prio now Current  size of the high priority queue 
26.  FSM msg queue hi-prio min Smallest size of the high priority queue 
27.  FSM msg queue hi-prio max Larges t size of the high priority queue 
28.  FSM msg queue lo-prio now Current  size of the low priority queue 
29.  FSM msg queue lo-prio min Smallest  size of the low priority queue 
30.  FSM msg queue lo-prio max Larges t size of the low priority queue 
31.  FSM msg queue dmig now Current size of the data migration queue 
32.  FSM msg queue dmig min Smallest size of the data migration queue 
33.  FSM msg queue dmig max Largest size of the data migration queue 
34.  FSM msg queue events now Cu rrent size of the event queue 
35.  FSM msg queue events min Smallest size of the event queue 
36.  FSM msg queue events max La rgest size of the event queue 
37.  FSM cache inode lookups Number of inodes that were found in the FSM's cache 
38.  FSM cache inode misses Number of inodes that were not found in the FSM's cache 
39.  FSM cache inode hits % Percentage of inodes found in the FSM cache 
40.  FSM cache free incore inodes now Cu rrent number of free in-core inodes 
41.  FSM cache free incore inodes min Minimum number of free in-core inodes 
42.  FSM cache free incore inodes max Maximum number of free in-core inodes
CVLOG Stats Defined 


 Stat Meaning 
43.  FSM cache buffer lookups Number of metadata  entries that were looked up by the FSM 
44.  FSM cache buffer misses Number of metadata entries that were not in the FSM's buffer 
cache 
45.  FSM cache buffer hits % Percentage of meta data entries that were found in the FSM's 
buffer cache 
46.  FSM cache free buffers now Number of free buffer cache blocks in the FSM 
47.  FSM cache free buffers min Minimum number of free buffer cache blocks in the FSM 
48.  FSM cache free buffers max Maximum number of free buffer cache blocks in the FSM 
49.  FSM cache attrs now Number of cvnodes cached by connected clients 
50.  FSM cache attrs min Minimum number of cvnodes cached by connected clients 
51.  FSM cache attrs max Maximum number of cvnodes cached by connected clients 
52.  FSM AllocSession sessions Number of times c lients allocated from their reserved space. 
53.  FSM AllocSession maxactive Maximum number of allocations from reserved space existing 
at one time 
54.  FSM AllocSession stolen Number of timed-out  reservations that were used by a later 
allocation 
55.  FSM AllocSession stolenmax Amount of reserved space that has been used 
56.  FSM extent lookups Number of time s the requested data block was found 
57.  FSM extent misses Number of times the requested data block was not found 
58.  FSM extent hits % Percentage of times the correct data block was found 
59.  FSM extent hint tries Number of times FSM searched the next extent, assuming it 
would return the requested data block 
60.  FSM extent hint misses Number of times the next extent in the list didn't reference the 
requested data block 
61.  FSM extent hint hits % Percentage of times the extent hint was correct 
62.  Lookup cnt/avg/min/max Find a file  or directory in a directory 
63.  Mkdir cnt/avg/min/max Create a directory 
64.  Create cnt/avg/min/max Create a file 
65.  Getattr cnt/avg/min/max Get the a ttributes of a file or directory 
66.  Readdir cnt/avg/min/max Read a directory 
67.  Setattr cnt/avg/min/max Set the attr ibutes of a file or directory 
68.  Rmdir cnt/avg/min/max Remove a directory 
69.  Remove cnt/avg/min/max Remove a file 
70.  Rename cnt/avg/min/max Rename a file or directory 
71.  Link cnt/avg/min/max Hard link a file or directory 
72.  AllocSpace cnt/avg/min/max Grow the size of a file 
73.  Open cnt/avg/min/max Open a file 
74.  GetMediaType cnt/avg/min/max Deprecated, no longer used 
75.  GetExtAttr cnt/avg/min/max Get the extended attributes for a file or directory 
76.  Close cnt/avg/min/max Close a file 
77.  Flush cnt/avg/min/max Deprecated, no longer used 
78.  ModifySpace cnt/avg/min/max Deprecated, no longer used 
79.  SymLink cnt/avg/min/max Create a symbolic link to a file 
80.  ReadLink cnt/avg/min/max Find the target of a symbolic link 
81.  MultiPathLookup cnt/avg/min/max Deprecated, no longer used
CVLOG Stats Defined 


 Stat Meaning 
82.  FullPathReverse cnt/avg/min/max Find the full path to  the root of the file system from a given file 
or directory 
83.  PunchHole cnt/avg/min/max Free disk space used  by part of file, creating a sparse file 
84.  ExpandInodes cnt/avg/min/max Expa nd the pool of available inodes 
85.  AllocSpaceApi cnt/avg/min/max Grow the size of a file 
86.  GetNTSecurity cnt/avg/min/max Returns the NT s ecurity descriptor associated with a file or 
directory 
87.  SetNTSecurity cnt/avg/min/max Sets the NT s ecurity descriptor for a file or directory 
88.  Flush2pc cnt/avg/min/max Flush client inodes to disk and free FSM internal inode cache 
89.  DirAttr cnt/avg/min/max Get the stats for files or directories inside a directory 
90.  SwapExtents cnt/avg/min/max Swap the allo cation of one file with that of another 
91.  Getquota cnt/avg/min/max Get quota values for a file or directory OR for a user or group 
92.  Setquota cnt/avg/min/max Set quota values for a user or group 
93.  GetPerfectFit cnt/avg/min/max Returns the number  of times a file was tested to see if it's 
marked for “perfect fit” 
94.  BulkCreate cnt/avg/min/max Create multiple files or directories 
95.  CreateV3 cnt/avg/min/max Create a file 
96.  LookupV3 cnt/avg/min/max Find a file  or directory in a directory 
97.  OpenRet cnt/avg/min/max Client is swit ching a file to a shared access state 
98.  VopDirattrV2 cnt/avg/min/max Get the stats for files or directories inside a directory 
99.  VopGetattrV4 cnt/avg/min/max Get the attributes of a file or directory 
100. VopLookupV4 cnt/avg/min/max Find a file  or directory in a directory 
101. SetPerfectFit cnt/avg/min/max Set a file to only allocate from free space that is exactly the size 
of the requested allocation 
102. GetAffinityList cnt/avg/min/max Get the list of unique affinity keys 
103. GetDMxattr cnt/avg/min/max Deprecated, no longer used 
104. VopCapNegotiate cnt/avg/min/max Return the capa bilities of the FSM running the file system 
105. VopReaddir2 cnt/avg/min/max Read a directory 
106. CreateV4 cnt/avg/min/max Create a file 
107. MkdirV4 cnt/avg/min/max Create a directory 
108. VopClientID cnt/avg/min/max Record the client identifier 
109. VopInsertBlobTag cnt/avg/min/max Us ed when de-duplicating a file 
110. VopSubTypeXattr cnt/avg/min/max Used when doing data migration 
111. BulkGetattr cnt/avg/min/max Get the attri butes of multiple files or directories 
112. GetResyncAttr cnt/avg/min/max Resynchr onize inode attributes with a client 
113. NotifyContMod cnt/avg/min/max Xsan Spotlight notif ication that the contents of a file changed 
114. GetLinkInfo cnt/avg/min/max Pro cess a reverse path lookup element in the path of the file 
115. FullSync cnt/avg/min/max Deprecated, no longer used 
116. TknRet cnt/avg/min/max 3.5-only; client is unblocking a synchronous inode change 
request 
117. InodeCacheCheck cnt/avg/min/max 3.5-only; de bugging hook, not used on production systems 
118. CreateV5 cnt/avg/min/max Create a file 
119. MkdirV5 cnt/avg/min/max Create a directory 
120. DataRequest cnt/avg/min/max Read or write a file 
121. PartRequest cnt/avg/min/max Return st ripe group information to a client
CVLOG Stats Defined 


 Stat Meaning 
122. SizeRequest cnt/avg/min/max Deprecated, no longer used 
123. MtimeRequest cnt/avg/min/max Deprecated, no longer used 
124. DataRequestV2 cnt/avg/min/max Read or write a file 
125. GetExtentListApi cnt/avg/min/max Get a group of extents for a file 
126. TokenRequestV2 cnt/avg/min/max Return stripe group information to a client 
127. TokenRequestV3 cnt/avg/min/max Read or write a file 
128. “Reserved9” cnt/avg/min/max Read or write a file using previously reserved space 
129. PartChange cnt/avg/min/max FSM informing clients that a stripe group has changed 
130. InodeChange cnt/avg/min/max Broadcasts of cha nged inodes to clients that have them cached 
131. OpenChange cnt/avg/min/max Broadcasts of files that have been opened to clients that have 
the inode cached 
132. FsChange cnt/avg/min/max Broadcasts of file system changes to all clients 
133. FileRevoke cnt/avg/min/max Deprecated, no longer used 
134. TokenChangeV4 cnt/avg/min/max Broadcasts of cha nged inodes to clients that have them cached 
135. TokenReqAlloc cnt/avg/min/max Read or write a file 
136. TokenChangeSync cnt/avg/min/max 3.5 only, not currently used 
137. TokenChangeV5 cnt/avg/min/max 3.5 only, broadcasts of  changed inodes to clients that have them 
cached 
138. HiPriWr cnt/maxq Number of IOs to the journal and the maximum number queued 
at any one time 
139. avg/min/max Time spent waiting for devi ce IO to complete at driver level 
140. sysavg/sysmin/sysmax Time spent waiting fo r device IO, including notification from 
driver 
141. avglen/minlen/maxlen Length, in bytes, of IOs 
142. Read cnt/maxq Number of read IOs to the metadata LUN and the maximum 
number queued at any one time 
143. avg/min/max Time spent waiting for devi ce IO to complete at driver level 
144. sysavg/sysmin/sysmax Time spent waiting fo r device IO, including notification from 
driver 
145. avglen/minlen/maxlen Length, in bytes, of IOs 
146. Write cnt/maxq Number of write IOs to  the metadata LUN and the maximum 
number queued at any one time 
147. avg/min/max Time spent waiting for devi ce IO to complete at driver level 
148. sysavg/sysmin/sysmax Time spent waiting fo r device IO, including notification from 
driver 
149. avglen/minlen/maxlen Length, in bytes, of IOs
