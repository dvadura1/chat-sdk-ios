//
//  BXMPPUserConnectionWrapper.h
//  XMPPChat
//
//  Created by Benjamin Smiley-andrews on 19/08/2016.
//  Copyright © 2016 deluge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ChatSDK/PUserConnection.h>
#import <ChatSDK/bSubscriptionType.h>

@interface BXMPPUserConnectionWrapper : NSObject {
    id<PUserConnection> _connection;
}

+(BXMPPUserConnectionWrapper *) wrapperWithConnection: (id<PUserConnection>) connection;
-(id) initWithConnection: (id<PUserConnection>) connection;

-(NSString *) ask;
-(void) setAsk: (NSString *) ask;

@end
