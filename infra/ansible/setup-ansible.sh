---
# setup-ansible.yml
# Ansible playbook for setting up low-level camera host video prerequisites 
# for Raspberry Pi 5 and Raspberry Pi Zero W 2 devices

- name: Setup Video Device Prerequisites on RPi5 Host
  hosts: rpi5_hosts
  become: yes
  vars:
    enable_v4l2: true
    enable_camera: true
    enable_libcamera: true
    v4l2_utils_packages:
      - v4l-utils
      - libv4l-dev
      - v4l2loopback-dkms
      - v4l2loopback-utils
    gstreamer_packages:
      - gstreamer1.0-tools
      - gstreamer1.0-plugins-base
      - gstreamer1.0-plugins-good
      - gstreamer1.0-plugins-bad
      - gstreamer1.0-plugins-ugly
    ffmpeg_packages:
      - ffmpeg
      - libavcodec-dev
      - libavformat-dev
      - libswscale-dev
    camera_packages:
      - libcamera-apps
      - libcamera-dev
      - python3-picamera2
      
  tasks:
    - name: Update package cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install essential video packages
      apt:
        name: "{{ item }}"
        state: present
      loop: "{{ v4l2_utils_packages + gstreamer_packages + ffmpeg_packages + camera_packages }}"

    - name: Load v4l2loopback module
      modprobe:
        name: v4l2loopback
        params: 'devices=4 video_nr=10,11,12,13 card_label="Virtual Camera 1,Virtual Camera 2,Virtual Camera 3,Virtual Camera 4" exclusive_caps=1,1,1,1'
        state: present
      when: enable_v4l2 | bool

    - name: Set v4l2loopback to load on boot
      lineinfile:
        path: /etc/modules-load.d/v4l2loopback.conf
        line: v4l2loopback
        create: yes
        mode: '0644'
      when: enable_v4l2 | bool

    - name: Configure v4l2loopback module parameters
      lineinfile:
        path: /etc/modprobe.d/v4l2loopback.conf
        line: 'options v4l2loopback devices=4 video_nr=10,11,12,13 card_label="Virtual Camera 1,Virtual Camera 2,Virtual Camera 3,Virtual Camera 4" exclusive_caps=1,1,1,1'
        create: yes
        mode: '0644'
      when: enable_v4l2 | bool

    - name: Enable camera interface in config.txt
      lineinfile:
        path: /boot/config.txt
        regexp: '^#?start_x='
        line: 'start_x=1'
      when: enable_camera | bool

    - name: Allocate GPU memory for camera
      lineinfile:
        path: /boot/config.txt
        regexp: '^#?gpu_mem='
        line: 'gpu_mem=128'
      when: enable_camera | bool

    - name: Enable V4L2 driver in config.txt
      lineinfile:
        path: /boot/config.txt
        line: 'dtoverlay=v4l2-codec,audio=0'
        create: yes
      when: enable_camera | bool

    - name: Create udev rules for video devices
      copy:
        dest: /etc/udev/rules.d/99-camera.rules
        content: |
          # Rules for RPi camera modules
          SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", ATTRS{name}=="Camera 0", SYMLINK+="video-main"
          SUBSYSTEM=="video4linux", KERNEL=="video1[0-9]*", ATTRS{name}=="Virtual Camera 1", SYMLINK+="video-virtual1"
          SUBSYSTEM=="video4linux", KERNEL=="video1[1-3]*", ATTRS{name}=="Virtual Camera [2-4]", SYMLINK+="video-virtual%n"
          
          # Give video group access to all video devices
          SUBSYSTEM=="video4linux", GROUP="video", MODE="0660"
        mode: '0644'

    - name: Ensure video group exists
      group:
        name: video
        state: present

    - name: Add user pi to video group
      user:
        name: pi
        groups: video
        append: yes

    - name: Install GStreamer Python bindings
      apt:
        name: python3-gst-1.0
        state: present

    - name: Create video testing script
      copy:
        dest: /usr/local/bin/test-video-devices.sh
        content: |
          #!/bin/bash
          echo "Listing available video devices:"
          v4l2-ctl --list-devices
          
          echo -e "\nChecking video device capabilities:"
          for dev in /dev/video*; do
            echo "Device: $dev"
            v4l2-ctl --device=$dev --all
            echo -e "\n----------------------------\n"
          done
          
          echo "Testing v4l2loopback devices:"
          for dev in /dev/video1[0-3]; do
            if [ -e "$dev" ]; then
              echo "Testing loopback on $dev"
              # Generate test pattern
              gst-launch-1.0 -v videotestsrc ! 'video/x-raw,width=640,height=480,framerate=30/1' ! v4l2sink device=$dev &
              PID=$!
              sleep 2
              # Capture a frame to verify
              ffmpeg -f v4l2 -i $dev -frames:v 1 -y /tmp/test_$(basename $dev).jpg
              kill $PID
              echo "Saved test frame to /tmp/test_$(basename $dev).jpg"
            fi
          done
        mode: '0755'

    - name: Create systemd service for v4l2 pipeline
      copy:
        dest: /etc/systemd/system/v4l2-pipeline.service
        content: |
          [Unit]
          Description=V4L2 Video Pipeline Service
          After=network.target
          
          [Service]
          Type=simple
          User=pi
          ExecStart=/usr/bin/gst-launch-1.0 v4l2src device=/dev/video0 ! videoconvert ! tee name=t ! queue ! v4l2sink device=/dev/video10 t. ! queue ! v4l2sink device=/dev/video11
          Restart=on-failure
          RestartSec=5
          
          [Install]
          WantedBy=multi-user.target
        mode: '0644'
      when: enable_v4l2 | bool

    - name: Enable v4l2 pipeline service
      systemd:
        name: v4l2-pipeline.service
        enabled: yes
        state: started
        daemon_reload: yes
      when: enable_v4l2 | bool

- name: Setup Video Device Prerequisites on RPiZW2 Peripheral
  hosts: rpizw2_peripherals
  become: yes
  vars:
    enable_camera: true
    camera_packages:
      - libcamera-apps
      - python3-picamera2
      - v4l-utils
      - ffmpeg
      
  tasks:
    - name: Update package cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install camera packages
      apt:
        name: "{{ camera_packages }}"
        state: present

    - name: Enable camera interface in config.txt
      lineinfile:
        path: /boot/config.txt
        regexp: '^#?start_x='
        line: 'start_x=1'
      when: enable_camera | bool

    - name: Allocate GPU memory for camera
      lineinfile:
        path: /boot/config.txt
        regexp: '^#?gpu_mem='
        line: 'gpu_mem=128'
      when: enable_camera | bool

    - name: Ensure video group exists
      group:
        name: video
        state: present

    - name: Add user pi to video group
      user:
        name: pi
        groups: video
        append: yes

    - name: Create camera streaming script
      copy:
        dest: /usr/local/bin/stream-camera.sh
        content: |
          #!/bin/bash
          # Stream camera over network to RPi5 host
          
          HOST_IP="{{ hostvars[groups['rpi5_hosts'][0]]['ansible_host'] }}"
          
          libcamera-vid -t 0 --width 1280 --height 720 --framerate 30 --inline --listen -o tcp://$HOST_IP:8888
        mode: '0755'

    - name: Create systemd service for camera streaming
      copy:
        dest: /etc/systemd/system/camera-stream.service
        content: |
          [Unit]
          Description=Camera Streaming Service
          After=network.target
          
          [Service]
          Type=simple
          User=pi
          ExecStart=/usr/local/bin/stream-camera.sh
          Restart=on-failure
          RestartSec=5
          
          [Install]
          WantedBy=multi-user.target
        mode: '0644'

    - name: Create stream receiver script on host
      delegate_to: "{{ item }}"
      copy:
        dest: /usr/local/bin/receive-camera-stream.sh
        content: |
          #!/bin/bash
          # Receive camera stream from peripheral and pipe to v4l2loopback
          
          gst-launch-1.0 tcpclientsrc host={{ ansible_host }} port=8888 ! h264parse ! avdec_h264 ! videoconvert ! v4l2sink device=/dev/video10
        mode: '0755'
      with_items: "{{ groups['rpi5_hosts'] }}"

    - name: Test camera functionality
      shell: |
        libcamera-still -o /tmp/test_camera.jpg
        echo "Camera test image saved to /tmp/test_camera.jpg"
      register: camera_test
      changed_when: false
      ignore_errors: true

    - name: Report camera test results
      debug:
        msg: "Camera test {{ 'successful' if camera_test.rc == 0 else 'failed' }}"