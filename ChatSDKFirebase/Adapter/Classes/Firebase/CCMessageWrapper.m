//
//  CCMessage.m
//  Chat SDK
//
//  Created by Benjamin Smiley-andrews on 10/02/2015.
//  Copyright (c) 2015 deluge. All rights reserved.
//

#import "CCMessageWrapper.h"

#import <ChatSDKFirebase/FirebaseAdapter.h>

@implementation CCMessageWrapper

+(id) messageWithSnapshot: (FIRDataSnapshot *) snapshot {
    return [[self alloc] initWithSnapshot:snapshot];
}

-(id) initWithSnapshot: (FIRDataSnapshot *) snapshot {
    if ((self = [self init])) {
        NSString * entityID = snapshot.key;
        _model = [BChatSDK.db fetchOrCreateEntityWithID:entityID withType:bMessageEntity];
        [self deserialize:snapshot.value];
    }
    return self;
}

+(id) messageWithModel: (id<PMessage>) model {
    return [[self alloc] initWithModel:model];
}

-(id) initWithModel: (id<PMessage>) model {
    if((self = [super init])) {
        _model = model;
    }
    return self;
}

#pragma DB Methods

+(id) messageWithID: (NSString *) entityID {
    id<PMessage> model = [BChatSDK.db fetchEntityWithID:entityID withType:bMessageEntity];
    if (!model) {
        model = [BChatSDK.db createMessageEntity];
    }
    return [[CCMessageWrapper alloc] initWithModel:model];
}

-(void) save {
    
}

#pragma Network Methods

-(RXPromise *) push {
    
    RXPromise * promise = [RXPromise new];

    // Add the message to Firebase
    FIRDatabaseReference * ref = [self ref];
    _model.entityID = ref.key;
    
    [ref setValue:[self serialize] andPriority: FIRServerValue.timestamp withCompletionBlock:^(NSError * error, FIRDatabaseReference * ref) {
        if (!error) {
            [promise resolveWithResult:self];
        }
        else {
            _model.entityID = Nil;
            [promise rejectWithReason:error];
        }
    }];
    
    return promise;
}

-(NSMutableDictionary *) serialize {
    
    NSDictionary * meta;
    if (BChatSDK.encryption) {
        meta = [BChatSDK.encryption encryptMessage:_model];
    }
    if (!meta) {
        meta = _model.meta;
    }
    
    NSDictionary * dict = @{bType: _model.type,
                             bDate: [FIRServerValue timestamp],
                             bReadPath: self.initialReadReceipts,
                             bMetaPath: meta,
                             bFrom: _model.userModel.entityID,
                             bTo: self.getTo};
    
    return [NSMutableDictionary dictionaryWithDictionary:dict];
}

-(NSArray<NSString *> *) getTo {
    NSMutableArray<NSString *> * users = [NSMutableArray new];
    for (id<PUser> user in _model.thread.users) {
        if (!user.isMe) {
            [users addObject:user.entityID];
        }
    }
    return users;
}

-(NSDictionary *) initialReadReceipts {
    // Setup the initial read receipts
    NSMutableDictionary * readReceipts = [NSMutableDictionary new];
    for (id<PUser> user in self.model.thread.users) {
        if (!user.isMe) {
            readReceipts[user.entityID] = @{bStatus: @(bMessageReadStatusNone), bDate: FIRServerValue.timestamp};
        } else {
            readReceipts[user.entityID] = @{bStatus: @(bMessageReadStatusRead), bDate: FIRServerValue.timestamp};
        }
    }
    return readReceipts;
}

-(RXPromise *) deserialize: (NSDictionary *) value {
    
    RXPromise * promise = [RXPromise new];
    NSString * entityID = BChatSDK.currentUser.entityID;
        
    NSNumber * messageType = value[bType];
    if (messageType) {
        _model.type = messageType;
    }
    
    NSNumber * date = value[bDate];
    if (date) {
        _model.date = [BFirebaseCoreHandler timestampToDate:date];
    }
    
    NSDictionary * readReceipts = value[bReadPath];
    if (readReceipts) {
        [_model setReadStatus:readReceipts];
        // TODO: Remove this
        //[_model setReadReceipts:readReceipts];
    }
    if ([readReceipts[entityID][bStatus] intValue] == bMessageReadStatusRead) {
        [_model setRead:@YES];
    }
    
    NSDictionary * meta = value[bMetaPath];
    if (meta) {
        if (BChatSDK.encryption) {
            NSString * data = meta[bMessageEncryptedPayloadKey];
            if (data) {
                NSDictionary * decrypted = [BChatSDK.encryption decryptMessage:data];
                if (decrypted) {
                    meta = decrypted;
                }
            }
        }
        [_model setMeta:meta];
    }
    
    // Assign this message to a user
    NSString * userID = value[bFrom];

    if (userID) {
        id<PMessage>(^onComplete)(id<PUser> user) = ^id<PMessage>(id<PUser> user) {
            self.model.userModel = user;
            [BHookNotification notificationMessageUpdated: self.model];
            return self.model;
        };
        
        id<PUser> user = [BChatSDK.db fetchEntityWithID:userID withType:bUserEntity];
        if (!user) {
            id<PUser> user = [BChatSDK.db fetchOrCreateEntityWithID:userID withType:bUserEntity];
            [promise resolveWithResult:[BChatSDK.core observeUser:user.entityID].thenOnMain(^id(id success) {
                return onComplete(user);
            }, Nil)];
        } else {
            [promise resolveWithResult:onComplete(user)];
        }
    }
    else {
        [promise resolveWithResult:Nil];
    }
    
    return promise;
}

-(RXPromise *) send {
    if (_model.thread) {

        return [self push].thenOnMain(^id(id success) {
            [self.model setDelivered:@YES];
            return [BEntity pushThreadMessagesUpdated:self.model.thread.entityID];
        }, Nil);
    }
    else {
        return [RXPromise rejectWithReason:Nil];
    }
}


-(RXPromise *) flag {
    RXPromise * promise = [RXPromise new];
    
    NSDictionary * data = @{bCreator: BChatSDK.currentUser.entityID,
                            bSenderEntityID: _model.userModel.entityID,
                            bFrom: _model.userModel.entityID,
                            bMessage: _model.meta,
                            bThread: _model.thread.entityID,
                            bDate: [FIRServerValue timestamp]};
    
    FIRDatabaseReference * ref = [FIRDatabaseReference flaggedRefWithMessage:_model.entityID];
    [ref setValue:data withCompletionBlock:^(NSError * error, FIRDatabaseReference * ref) {
        if (!error) {
            _model.flagged = @YES;
            [promise resolveWithResult:Nil];
        }
        else {
            [promise rejectWithReason:error];
        }
    }];
    return promise;
}

-(RXPromise *) unflag {
    RXPromise * promise = [RXPromise new];
    FIRDatabaseReference * ref = [FIRDatabaseReference flaggedRefWithMessage:_model.entityID];

    [ref removeValueWithCompletionBlock:^(NSError * error, FIRDatabaseReference * ref) {
        if (!error) {
            self.model.flagged = @NO;
            [promise resolveWithResult:Nil];
        }
        else {
            [promise rejectWithReason:error];
        }
    }];
    return promise;
}

-(RXPromise *) delete {
    RXPromise * promise = [RXPromise new];
    
    FIRDatabaseReference *ref = [[FIRDatabaseReference threadMessagesRef:_model.thread.entityID] child:_model.entityID];
    [ref removeValueWithCompletionBlock:^(NSError * error, FIRDatabaseReference * ref) {
        if (!error) {
            [promise resolveWithResult:Nil];
        }
        else {
            [promise rejectWithReason:error];
        }
    }];

    return promise;
}

-(FIRDatabaseReference *) ref {
    if (_model.entityID) {
        return [FIRDatabaseReference thread:_model.thread.entityID messageRef:_model.entityID];
   }
    else {
        return [[FIRDatabaseReference threadMessagesRef:_model.thread.entityID] childByAutoId];
    }
}

-(void) setDelivered: (NSNumber *) delivered {
    [_model setDelivered:delivered];
}

-(id<PMessage>) model {
    return _model;
}

-(NSString *) entityID {
    return _model.entityID;
}

-(RXPromise *) markAsReceived {
    return [self setReadStatus:bMessageReadStatusDelivered];
}

-(RXPromise *) setReadStatus: (bMessageReadStatus) status {
    
    // Don't set read status for our own messages
    if(_model.senderIsMe) {
        return [RXPromise resolveWithResult:Nil];
    }
    
    NSString * entityID = BChatSDK.currentUser.entityID;
    
    // Check to see if we've already set the status?
    bMessageReadStatus currentStatus = [_model readStatusForUserID:entityID];
    
    // If the status is the same or lower than the new status just return
    if (currentStatus >= status) {
        return [RXPromise resolveWithResult:Nil];
    }
    
    if (status == bMessageReadStatusRead) {
        
    }
    
    // Set the status - this prevents a race condition where
    // the message is to set to be delivered later
    [_model setReadStatus:status forUserID:entityID];
    
    // Set our status area
    RXPromise * promise = [RXPromise new];

    FIRDatabaseReference * ref = [FIRDatabaseReference thread:_model.thread.entityID messageReadRef:_model.entityID];
    
    [[ref child: entityID] setValue:@{bStatus: @(status), bDate: FIRServerValue.timestamp} withCompletionBlock:^(NSError * error, FIRDatabaseReference * ref ) {
        if (!error) {
            [promise resolveWithResult:Nil];
        }
        else {
            [promise rejectWithReason:error];
        }
    }];
    
    return promise;
    
}

@end
