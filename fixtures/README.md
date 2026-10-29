# Fixtures

task-session.json is an author-owned synthetic three-frame task incident: builder PID 100, worker PID 200 and an external cache holder PID 900. The worker is observed waiting in the first two frames and runnable without that lock wait in the third. scripts/create_task_fixture.py reproduces it without reading any host data. It is not a real procfs capture.

contention.locks is synthetic, authored for this project. PIDs, device numbers and inodes do not describe a host. Spacing follows Linux v6.12 locks_show/lock_get_status. It includes two-level waiting, siblings, OFD unknown owner and a breaking lease. Kernel snapshots from integration runs stay in release-local and are not redistributed.

file-session.json 是自有 synthetic OFD 三帧会话：两次观察到 unknown-owner 锁等待，第三次未再观察到等待。未使用宿主真实路径或进程数据。
