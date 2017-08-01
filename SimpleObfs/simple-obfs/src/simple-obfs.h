//
//  simple-obfs.h
//  ThroughWall
//
//  Created by Bin on 01/08/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

#ifndef simple_obfs_h
#define simple_obfs_h

typedef void (*simpleobfs_cb) (void*);

typedef struct  {
    char *ss_remote_host;
    char *ss_remote_port;
    char *ss_local_host;
    char *ss_local_port;
    char *ss_plugin_opts;
}profile_t;

int
simple_obfs_start(profile_t profile, simpleobfs_cb cb, void * data);

unsigned short get_local_port();

#endif /* simple_obfs_h */
