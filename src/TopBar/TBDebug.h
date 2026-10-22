#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef DEBUG
void TBDebugLog(NSString *format, ...);
#else
#define TBDebugLog(...) do {} while (0)
#endif

#ifdef __cplusplus
}
#endif
