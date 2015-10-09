//
//  Matrix4.h
//  HelloMetal
//
//  Created by Andrew K. on 6/27/14.
//  Copyright (c) 2014 Andrew Kharchyshyn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKMath.h>

// Wraper around GLKMath's GLKMatrix4, becouse we can't use it directly from Swift code

@interface Matrix4 : NSObject{
@public
  GLKMatrix4 glkMatrix;
}

+ (Matrix4 *)makePerspectiveViewAngle:(float)angleRad
                          aspectRatio:(float)aspect
                                nearZ:(float)nearZ
                                 farZ:(float)farZ;

- (instancetype)init;
- (instancetype)copy;


- (void)scale:(float)x y:(float)y z:(float)z;
- (void)rotateAroundX:(float)xAngleRad y:(float)yAngleRad z:(float)zAngleRad;
- (void)translate:(float)x y:(float)y z:(float)z;
- (void)multiplyLeft:(Matrix4 *)matrix;


- (void *)raw;
- (void)transpose;

+ (float)degreesToRad:(float)degrees;
+ (NSInteger)numberOfElements;

@end
