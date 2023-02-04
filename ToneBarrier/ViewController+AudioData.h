//
//  ViewController+AudioData.h
//  ToneBarrier
//
//  Created by Xcode Developer on 2/2/23.
//

#import "ViewController.h"

@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

static const uintptr_t (^(^generator)(const uintptr_t, const size_t, const size_t))(void) = ^ (const uintptr_t start, const size_t stride, const size_t length) {
    static uintptr_t index;
    index = start;
    static uintptr_t end;
    end = start + (stride * length); // replace with comparison between value of static counter variable to length
    return ^ const uintptr_t {
        // (increment index AND test whether to restart index) & (test buffer at index for null)
        return ((index & end)); // (index = (({ (index += stride); }) ^ end) & index);
//        return (result = ((result += stride) < end) ? result : start);
    };
};



/*
 
 */

// Collection pointer
// An audio buffer is an aggregate (samples) of discrete (frame_count) audio signal data
typedef typeof(void **(^)(void)) sample_signal; // samples the audio signal buffer (returns a pointer to an audio sample)
static typeof(sample_signal) (^_Nonnull audio_signal)(size_t) = ^ (size_t frame_count) {
    typedef void * audio_buffer_ref[frame_count];
    typeof(audio_buffer_ref) signal_samples[frame_count];
    __block void ** signal_sample_t = signal_samples[0];
    return ^ (void ** signal_sample_ptr) {
        return (^ void ** {
            return  signal_sample_ptr;
        });
    }(signal_sample_t);
};

typedef typeof(uint32_t **(^)(void)) element_ptr;
static typeof(element_ptr) (^_Nonnull collection)(size_t) = ^ (size_t element_count) {
    typedef uint32_t * collection_type_ref[element_count];
    typeof(collection_type_ref) collection[element_count];
    __block uint32_t ** element = collection[0];
    return ^ (uint32_t ** element_ptr) {
        __block uint32_t element_index;
        return (^ uint32_t ** {
            return ^ (const uint32_t index) { // To-Do:
                return ((uint32_t **)element_ptr + (uint32_t)(index));
            }(~-element_index);
            // conditions to consider:
            //      if element_count - element_index == 0, create a new collection (will have to retain a pointer-block so caller can reuse between each new collection
            //      if element_ptr == NULL, same as above
            //      if element_index !+ element_count, add element_index to element_ptr and return
            //      if
        });
    }(element);
};

//static const unsigned int (^(^generator)(const unsigned int))(const unsigned int) = ^ (const unsigned int frame_count) {
//    return ^ const unsigned int (const unsigned int frame_index) {
//        return ^ (const unsigned int frame_index) {
//            return (frame_index & (logic(-~frame_index) ^ frame_count));
//        };
//    };
//};

// Element pointer generator (element access)
//typedef typeof(void **(^)(size_t)) stream;
//static typeof(stream) (^ _Nonnull elements)(typeof(audio_sample_ptr), size_t) = ^ (typeof(audio_sample_ptr) source, size_t stride) {
//    return ^ (void ** source_ptr) {
//        return (^ void ** (size_t index) {
//            return ((void **)source_ptr + (index * stride));
//        });
//    }(source());
//};
//
//// Element index iterator (element traversal)
////
//
//// Applies an operation to an element in a given collection using the supplied pointer
//static void (^(^operation)(void *))(void **) = ^ (void * value) {
//    return ^ (void ** element_ptr) {
//        *(element_ptr) = value;
//    };
//};


@interface ViewController (AudioData)

@end

NS_ASSUME_NONNULL_END
