#ifndef CSKYLIGHT_H
#define CSKYLIGHT_H

#include <CoreGraphics/CoreGraphics.h>

typedef int CGSConnectionID;

// Private SkyLight.framework symbols. Availability on macOS 26.x is exactly
// what this spike must determine.
extern CGSConnectionID SLSMainConnectionID(void);
extern CGError SLSGetWindowBounds(CGSConnectionID cid, uint32_t wid, CGRect *outBounds);
extern CGError SLSMoveWindow(CGSConnectionID cid, uint32_t wid, const CGPoint *point);
extern CGError SLSSetWindowFrame(CGSConnectionID cid, uint32_t wid, CGRect frame);

#endif
