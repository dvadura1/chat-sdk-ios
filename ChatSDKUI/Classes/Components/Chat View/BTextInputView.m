//
//  BTextInputView.m
//  Chat SDK
//
//  Created by Benjamin Smiley-andrews on 25/09/2013.
//  Copyright (c) 2013 deluge. All rights reserved.
//

#import "BTextInputView.h"
#import <ChatSDK/Core.h>
#import <ChatSDK/UI.h>

#define bMargin 24.0
#define bVerticalMargin 8.0

// The amount of padding (above + below) the text
// i.e. textView height = text height + padding
#define bTextViewVerticalPadding 5.72

#define bFontSize 19
#define bMaxLines 5
#define bMinLines 1
#define bMaxCharacters 0

@implementation BTextInputView

@synthesize textView = _textView;
@synthesize maxLines, minLines, maxCharacters;
@synthesize sendBarDelegate = _sendBarDelegate;
@synthesize optionsButton = _optionsButton;
@synthesize sendButton = _sendButton;
@synthesize placeholderLabel = _placeholderLabel;
@synthesize sendListener;

-(instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
        _readOnly = false;

        //        self.barTintColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.7];
        
        if (@available(iOS 13.0, *)) {
            self.backgroundColor = [UIColor systemBackgroundColor];
        } 

        // Decide how many lines the message should have
        minLines = bMinLines;
        maxLines = bMaxLines;
        maxCharacters = bMaxCharacters;
        
        // Set the text color
        // DM darkGrayColor
        
        if (@available(iOS 13.0, *)) {
            _placeholderColor = [UIColor systemGrayColor];
        } else {
            _placeholderColor = [UIColor grayColor];
        }

        _textColor = [UIColor blackColor];

        // Create an options button which shows an action sheet
        _optionsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self addSubview:_optionsButton];

        _textView = [[HKWTextView alloc] init];
        // If we use the mentions functionality we need to set the external delegate
        // This is the way to set the UITextView delegate to keep mentions functionality working
        _textView.simpleDelegate = self;
      
        [self addSubview: _textView];

        // Add a send button
        _sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self addSubview: _sendButton];
        
        [_optionsButton setImage:[NSBundle uiImageNamed:@"icn_24_options"] forState:UIControlStateNormal];
        [_optionsButton setImage:[NSBundle uiImageNamed:@"icn_24_keyboard"] forState:UIControlStateSelected];
        
        [_optionsButton addTarget:self action:@selector(optionsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        NSString * sendButtonTitle = [NSBundle t:bSend];
        [_sendButton setTitle:sendButtonTitle forState:UIControlStateNormal];
        
        [_sendButton addTarget:self action:@selector(sendButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_sendButton addTarget:self action:@selector(sendButtonHeld) forControlEvents:UIControlEventTouchDown];
        
        // We don't want to send a message if they touch up outside the button area
        [_sendButton addTarget:self action:@selector(sendButtonCancelled) forControlEvents:UIControlEventTouchUpOutside];
        
        _textView.scrollEnabled = YES;
        _textView.backgroundColor = [UIColor clearColor];
        
        // For some reason using scrollEnabled = NO causes probalems
        _textView.bounces = NO;
        
        // Adjust the insets to make the text closer to the outside of the
        // box - ios6 is slightly different from ios7
        if ([UIDevice currentDevice].systemVersion.intValue < 7) {
//            _textView.contentInset = UIEdgeInsetsMake(-6.0, -4.0, -6.0, 0.0);
        }
        else {
//            _textView.contentInset = UIEdgeInsetsMake(-6.0, -1.0, -6.0, 0.0);
        }

        // Constrain the elements
        _optionsButton.keepLeftInset.equal = (bMargin - 5) +keepRequired;

        _optionsButton.keepBottomInset.equal = 0;
        _optionsButton.keepHeight.equal = 40;
        
        // If the user has no chat options available then remove the chat option button width
        _optionsButton.keepWidth.equal = BChatSDK.ui.chatOptions.count ? 40 : 0;
        
        _optionsButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        _sendButton.keepRightInset.equal = bMargin - 5;
        _sendButton.keepBottomInset.equal = 0;
        _sendButton.keepHeight.equal = 40;
        _sendButton.keepWidth.equal = 40;
        _sendButton.translatesAutoresizingMaskIntoConstraints = NO;
                
        _textView.keepLeftOffsetTo(_optionsButton).equal = 0;
        _textView.keepRightOffsetTo(_sendButton).equal = 12;
        _textView.keepBottomInset.equal = 1;
        _textView.keepTopInset.equal = 2;
        _textView.translatesAutoresizingMaskIntoConstraints = NO;

        // Create a placeholder text label
        _placeholderLabel = [[UILabel alloc] init];
        [self addSubview:_placeholderLabel];
        
        _placeholderLabel.keepBottomInset.equal = 2;
        _placeholderLabel.keepTopInset.equal = 2;
        _placeholderLabel.keepLeftOffsetTo(_optionsButton).equal = 8;
        _placeholderLabel.keepWidth.equal = 200;
        [_placeholderLabel setBackgroundColor:[UIColor clearColor]];
        
        [_placeholderLabel setTextColor:_placeholderColor];
        
        [_placeholderLabel setText:[NSBundle t:bWriteSomething]];
        
        [self setFont:[UIFont systemFontOfSize:bFontSize]];
        
        __weak __typeof__(self) weakSelf = self;
        _internetConnectionHook = [BHook hookOnMain:^(NSDictionary * data) {
            [weakSelf updateInterfaceForReachabilityStateChange];
        }];
        [BChatSDK.hook addHook:_internetConnectionHook withName:bHookInternetConnectivityDidChange];

        _connectionStatusHook = [BHook hookOnMain:^(NSDictionary * data) {
            [weakSelf updateInterfaceForReachabilityStateChange];
        }];
        [BChatSDK.hook addHook:_connectionStatusHook withName:bHookServerConnectionStatusUpdated];
        
        [self updateInterfaceForReachabilityStateChange];
        
        UIView * topMarginView = [[UIView alloc] initWithFrame:CGRectZero];
        
        // DM lightGrayColor
        if (@available(iOS 13.0, *)) {
            topMarginView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0] : [UIColor colorWithRed:0.88 green:0.88 blue:0.88 alpha:1.0];
            }];
        } else {
            topMarginView.backgroundColor = [UIColor colorWithRed:0.88 green:0.88 blue:0.88 alpha:1.0];
        }
        
        [self addSubview:topMarginView];
        
        topMarginView.keepBottomInset.equal = 0.0 + keepRequired;
        topMarginView.keepLeftInset.equal = 24.0 + keepRequired;
        topMarginView.keepRightInset.equal = 24.0 + keepRequired;
        topMarginView.keepHeight.equal = 1.0 + keepRequired;
        
        [self resizeToolbar];
    }
    return self;
}

-(void) updateInterfaceForReachabilityStateChange {
    _sendButton.enabled = self.isConnected && !_readOnly;
    _optionsButton.enabled = self.isConnected && !_readOnly;
}

-(BOOL) isConnected {
    BOOL connected = YES;
    if (BChatSDK.config.disableSendButtonWhenNotReachable) {
        connected = connected && BChatSDK.connectivity.isConnected;
    }
    if (BChatSDK.config.disableSendButtonWhenDisconnected) {
        connected = connected && (BChatSDK.core.connectionStatus == bConnectionStatusConnected || BChatSDK.core.connectionStatus == bConnectionStatusNone);
    }
    return connected;
}

-(void) setAudioEnabled: (BOOL) audioEnabled {
    _audioEnabled = audioEnabled;
    [self setMicButtonEnabled:_audioEnabled];
}

-(void) setMicButtonEnabled: (BOOL) enabled {
    [self setMicButtonEnabled:enabled sendButtonEnabled:NO];
}

-(void) setMicButtonEnabled: (BOOL) enabled sendButtonEnabled: (BOOL) sendButtonEnabled {
    _micButtonEnabled = enabled && self.isConnected;
    _sendButton.enabled = (sendButtonEnabled || enabled) && self.isConnected && !_readOnly;
    if (enabled) {
        [_sendButton setTitle:Nil forState:UIControlStateNormal];
        [_sendButton setImage:[NSBundle uiImageNamed: @"icn_24_mic"]
                     forState:UIControlStateNormal];
    }
    else {
        [_sendButton setTitle:[NSBundle t:bSend] forState:UIControlStateNormal];
        [_sendButton setImage:Nil forState:UIControlStateNormal];
    }
}

#pragma Button Delegates

-(void) sendButtonPressed {
    if (_audioMaxLengthReached) {
        _audioMaxLengthReached = NO;
        return;
    }

    [self stopRecording];

    if (!_micButtonEnabled) {
        
        // Check if the message is empty
        if ([[_textView.text stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@""]) {
            return;
        }

        if (sendListener) {
            sendListener();
        }

        _textView.text = @"";
        [self textViewDidChange:_textView];
    }
    else {
        [self sendAudioMessage];
    }
}

// When the button is held we start recording
- (void)sendButtonHeld {
    if (_micButtonEnabled) {
        [[BAudioManager shared] startRecording];
        
        __weak __typeof(self) weakSelf = self;
        _recordingToastTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * timer) {
            __typeof(self) strongSelf = weakSelf;
            [strongSelf showRecordingToast];
        }];

        _recordingStart = [NSDate new];
        [_placeholderLabel setText:[NSBundle t: bSlideToCancel]];
    }
}

-(void) sendAudioMessage {
    // This is where the button is released so we want to finish recording and send
    if (_sendBarDelegate) {
        
        // Return the recording url and duration in an array
        NSURL * audioURL = [BAudioManager shared].recorder.url;
        NSData * audioData = [NSData dataWithContentsOfURL:audioURL];
        double duration = [BAudioManager shared].recordingLength;
        
        if (duration > 1) {
            [BChatSDK.audioMessage sendMessageWithAudio:audioData duration:duration withThreadEntityID:_sendBarDelegate.threadEntityID];
        }
        else {
            // TODO: Make the tost position above the text bar programatically
            UIView * view = _sendBarDelegate.viewController.view;
            [view makeToast:[NSBundle t:bHoldToSendAudioMessageError]
                        duration:2
                        position:[NSValue valueWithCGPoint: CGPointMake(view.frame.size.width / 2.0, view.frame.size.height - 120)]];
            
        }
    }
}

-(void) showRecordingToast {
    NSString * text = [NSBundle t:bRecording];
    
    int remainingTime = BChatSDK.config.audioMessageMaxLengthSeconds + [_recordingStart timeIntervalSinceNow];
    if (remainingTime <= 10) {
        text = [NSString stringWithFormat:[NSBundle t: bSecondsRemaining_], remainingTime];
    }
    if (remainingTime <= 0) {
        _audioMaxLengthReached = YES;
        [self stopRecording];
        [self presentAlertView];
    }
    [_sendBarDelegate.view makeToast:text
                            duration:0.7
                            position:[NSValue valueWithCGPoint: CGPointMake(_sendBarDelegate.view.frame.size.width / 2.0, self.frame.origin.y - self.frame.size.height - 20)]];
}

-(void) stopRecording {
    [[BAudioManager shared] finishRecording];
    [_sendBarDelegate.view hideAllToasts];
    [_placeholderLabel setText:[NSBundle t:bWriteSomething]];
    [self cancelRecordingToastTimer];
}

-(void) presentAlertView {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSBundle t:bAudioLengthLimitReached]
                                                                   message:[NSBundle t:bSendOrDiscardRecording]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.popoverPresentationController.barButtonItem = Nil;

    UIAlertAction *submit = [UIAlertAction actionWithTitle:[NSBundle t:bSend] style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [self sendAudioMessage];
                                                   }];
    
    UIAlertAction * cancel = [UIAlertAction actionWithTitle:[NSBundle t:bCancel] style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }];
    
    [alert addAction:submit];
    [alert addAction:cancel];
    
    [self.sendBarDelegate.viewController presentViewController:alert animated:YES completion:Nil];

}

-(void) cancelRecordingToastTimer {
    if(_recordingToastTimer) {
        [_recordingToastTimer invalidate];
        _recordingToastTimer = Nil;
        _recordingStart = Nil;
    }
}

// If the user touches up off the button we cancel the recording
- (void)sendButtonCancelled {
    [_sendBarDelegate.view hideAllToasts];
    [_placeholderLabel setText:[NSBundle t:bWriteSomething]];

    CSToastStyle * style = [[CSToastStyle alloc] initWithDefaultStyle];
    if (@available(iOS 13.0, *)) {
        style.backgroundColor = [UIColor systemRedColor];
    } else {
        style.backgroundColor = [UIColor redColor];
    }

    [_sendBarDelegate.view makeToast:[NSBundle t:bCancelled]
                            duration:1
                            position:[NSValue valueWithCGPoint: CGPointMake(_sendBarDelegate.view.frame.size.width / 2.0, self.frame.origin.y - self.frame.size.height - 20)] style:style];
    [self cancelRecordingToastTimer];
    [[BAudioManager shared] finishRecording];
}

-(void) optionsButtonPressed {
    if (_optionsButton.selected) {
        [self hideOptions];
    }
    else {
        [self showOptions];
    }
}

-(void) showOptions {
    if (_sendBarDelegate && [_sendBarDelegate respondsToSelector:@selector(showOptions)]) {
        if([_sendBarDelegate showOptions]) {
            _optionsButton.selected = YES;
        }
    }
}

-(void) hideOptions {
    if (_sendBarDelegate && [_sendBarDelegate respondsToSelector:@selector(showOptions)]) {
        if([_sendBarDelegate hideOptions]) {
            _optionsButton.selected = NO;
        }
    }
}

-(void) setFont: (UIFont *) font {
    [_textView setFont:font];
    [_placeholderLabel setFont:font];
    [self resizeToolbar];
}

-(float) getTextHeight: (NSString *) text {
    NSString * nonBlankText = text;//[text stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    return [nonBlankText boundingRectWithSize:CGSizeMake(_textView.contentSize.width, CGFLOAT_MAX)
                                   options:NSStringDrawingUsesLineFragmentOrigin
                                attributes:@{NSFontAttributeName: _textView.font}
                                   context:Nil].size.height;
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    // Typing Indicator
    if (_sendBarDelegate && [_sendBarDelegate respondsToSelector:@selector(typing)]) {
        [_sendBarDelegate typing];
    }
    
    // Workout if adding this text will cause the box to become too long
    NSString * newText = [textView.text stringByAppendingString:text];
    
    if(maxCharacters > 0 && newText.length > maxCharacters) {
        return NO;
     }
    
    NSInteger numberOfLines = [self getTextHeight:newText]/textView.font.lineHeight;
    numberOfLines = MAX(numberOfLines, [newText componentsSeparatedByString:@"\n"].count);
    
    if (numberOfLines > maxLines) {
        return NO;
    }
    
    else return YES;
}

-(void) textViewDidChange:(UITextView *)textView {
    
    // If there is text or if the audio is turned off
    if (textView.text.length || !_audioEnabled) {
        [self setMicButtonEnabled:NO sendButtonEnabled:textView.text.length];
    }
    else {
        [self setMicButtonEnabled:YES];
    }
    
    
    [self resizeToolbar];

    // If the text area is empty show the placeholder
    _placeholderLabel.hidden = ![textView.text isEqualToString:@""];
}

-(void) setText: (NSString *) text {
    _textView.text = text;
    [self textViewDidChange:_textView];
    [self resizeToolbar];
}

-(NSString *) text {
    return _textView.text;
}

-(void) resizeToolbar {
    
    float originalHeight = self.keepHeight.equal;
    
//    float newHeight = MAX(_textView.contentSize.height, _textView.font.lineHeight);//[self getTextBoxTextHeight];
    float newHeight = MAX(_textView.font.lineHeight, [self measureHeightOfUITextView:_textView]);
    
    // Calcualte the new textview height
    float textBoxHeight = MIN(newHeight + bTextViewVerticalPadding, 122.0);

    // Set the toolbar height - the text view will resize automatically
    // using autolayout
    self.keepHeight.equal = textBoxHeight;
    
    float delta = self.keepHeight.equal - originalHeight;
    
    if(fabsf(delta) > 0.01) {
        [self.superview setNeedsUpdateConstraints];
        
        __weak __typeof__(self) weakSelf = self;
        
        [UIView animateWithDuration:0.2 animations:^{
            __typeof__(self) strongSelf = weakSelf;
            
            //[self setNeedsUpdateConstraints];
            [strongSelf.superview layoutIfNeeded];
            [strongSelf->_textView setContentOffset:CGPointZero animated:NO];

            if(strongSelf->_sendBarDelegate != Nil) {
                [strongSelf->_sendBarDelegate didResizeTextInputViewWithDelta:delta];
            }
        }];
    }
}

- (CGFloat)measureHeightOfUITextView:(UITextView *)textView
{
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        // This is the code for iOS 7. contentSize no longer returns the correct value, so
        // we have to calculate it.
        //
        // This is partly borrowed from HPGrowingTextView, but I've replaced the
        // magic fudge factors with the calculated values (having worked out where
        // they came from)
        
        CGRect frame = textView.bounds;
        
        // Take account of the padding added around the text.
        
        UIEdgeInsets textContainerInsets = textView.textContainerInset;
        UIEdgeInsets contentInsets = textView.contentInset;
        
        CGFloat leftRightPadding = textContainerInsets.left + textContainerInsets.right + textView.textContainer.lineFragmentPadding * 2 + contentInsets.left + contentInsets.right;
        CGFloat topBottomPadding = textContainerInsets.top + textContainerInsets.bottom + contentInsets.top + contentInsets.bottom;
        
        frame.size.width -= leftRightPadding;
        frame.size.height -= topBottomPadding;
        
        NSString *textToMeasure = textView.text;
        if ([textToMeasure hasSuffix:@"\n"])
        {
            textToMeasure = [NSString stringWithFormat:@"%@-", textView.text];
        }
        
        // NSString class method: boundingRectWithSize:options:attributes:context is
        // available only on ios7.0 sdk.
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
        
        NSDictionary *attributes = @{ NSFontAttributeName: textView.font, NSParagraphStyleAttributeName : paragraphStyle };
        
        CGRect size = [textToMeasure boundingRectWithSize:CGSizeMake(CGRectGetWidth(frame), MAXFLOAT)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:attributes
                                                  context:nil];
        
        CGFloat measuredHeight = ceilf(CGRectGetHeight(size) + topBottomPadding);
        return measuredHeight;
    }
    else
    {
        return textView.contentSize.height;
    }
}

-(void) setOptionsButtonHidden: (BOOL) hidden {
    _optionsButton.keepWidth.equal = hidden ? 0 : 24;
}

-(BOOL) resignTextViewFirstResponder {
//    [super resignFirstResponder];
    [self hideOptions];
    return [_textView resignFirstResponder];
}

-(void) becomeTextViewFirstResponder {
//    [super becomeFirstResponder];
    [_textView becomeFirstResponder];
}

-(void) setSendBarDelegate:(id<PSendBarDelegate>)delegate {
    _sendBarDelegate = delegate;
}

-(void) setReadOnly: (BOOL) readonly {
    _readOnly = readonly;
    
    _optionsButton.enabled = !readonly;
    _textView.userInteractionEnabled = !readonly;
    _placeholderLabel.hidden = readonly;
    _sendButton.enabled = !readonly;
    
}

@end
