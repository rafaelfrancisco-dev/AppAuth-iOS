/*! @file OIDExternalUserAgentVision.m
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2016 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import <TargetConditionals.h>

#if TARGET_OS_VISION

#import "OIDExternalUserAgentVision.h"

#import <AuthenticationServices/AuthenticationServices.h>

#import "OIDErrorUtilities.h"
#import "OIDExternalUserAgentSession.h"
#import "OIDExternalUserAgentRequest.h"


NS_ASSUME_NONNULL_BEGIN

@interface OIDExternalUserAgentVision ()<ASWebAuthenticationPresentationContextProviding>
@end

@implementation OIDExternalUserAgentVision {
  BOOL _externalUserAgentFlowInProgress;
  __weak id<OIDExternalUserAgentSession> _session;
  BOOL _prefersEphemeralSession;

  UIWindow *_presentingWindow;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  ASWebAuthenticationSession *_webAuthenticationSession;
#pragma clang diagnostic pop
}

- (instancetype)initWithPresentingWindow:(UIWindow *)presentingWindow {
  self = [super init];
  if (self) {
    _presentingWindow = presentingWindow;
  }
  return self;
}

- (nullable instancetype)initWithPresentingWindow:(UIWindow *)presentingWindow
                          prefersEphemeralSession:(BOOL)prefersEphemeralSession {
  self = [self initWithPresentingWindow:presentingWindow];
  if (self) {
    _prefersEphemeralSession = prefersEphemeralSession;
  }
  return self;
}

- (instancetype)init {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  return [self initWithPresentingWindow:nil];
#pragma clang diagnostic pop
}

- (BOOL)presentExternalUserAgentRequest:(id<OIDExternalUserAgentRequest>)request
                                session:(id<OIDExternalUserAgentSession>)session {
  if (_externalUserAgentFlowInProgress) {
    // TODO: Handle errors as authorization is already in progress.
    return NO;
  }

  _externalUserAgentFlowInProgress = YES;
  _session = session;
  NSURL *requestURL = [request externalUserAgentRequestURL];

    if (_presentingWindow) {
        __weak OIDExternalUserAgentVision *weakSelf = self;
        NSString *redirectScheme = request.redirectScheme;
        ASWebAuthenticationSession *authenticationSession;
        if (@available(visionOS 1.1, *)) {
            authenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:requestURL
                                                 callback: [ASWebAuthenticationSessionCallback callbackWithCustomScheme: redirectScheme]
                                        completionHandler:^(NSURL * _Nullable callbackURL,
                                                            NSError * _Nullable error) {
            __strong OIDExternalUserAgentVision *strongSelf = weakSelf;
            if (!strongSelf) {
              return;
            }
            strongSelf->_webAuthenticationSession = nil;
            if (callbackURL) {
              [strongSelf->_session resumeExternalUserAgentFlowWithURL:callbackURL];
            } else {
              NSError *safariError =
              [OIDErrorUtilities errorWithCode:OIDErrorCodeUserCanceledAuthorizationFlow
                               underlyingError:error
                                   description:nil];
              [strongSelf->_session failExternalUserAgentFlowWithError:safariError];
            }
          }];
          
        } else {
            authenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:requestURL
                                          callbackURLScheme:redirectScheme
                                          completionHandler:^(NSURL * _Nullable callbackURL,
                                                              NSError * _Nullable error) {
            __strong OIDExternalUserAgentVision *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_webAuthenticationSession = nil;
            if (callbackURL) {
              [strongSelf->_session resumeExternalUserAgentFlowWithURL:callbackURL];
            } else {
              NSError *safariError =
                  [OIDErrorUtilities errorWithCode:OIDErrorCodeUserCanceledAuthorizationFlow
                                   underlyingError:error
                                       description:nil];
              [strongSelf->_session failExternalUserAgentFlowWithError:safariError];
            }
            }];
        }

        authenticationSession.presentationContextProvider = self;

        _webAuthenticationSession = authenticationSession;
        _webAuthenticationSession.prefersEphemeralWebBrowserSession = _prefersEphemeralSession;
        if (authenticationSession.canStart) {
            return [authenticationSession start];
        } else {
            return NO;
        }
    }
  

    [[UIApplication sharedApplication] openURL:requestURL options: [NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> new] completionHandler:nil];
  /*if (!openedBrowser) {
    [self cleanUp];
    NSError *safariError = [OIDErrorUtilities errorWithCode:OIDErrorCodeBrowserOpenError
                                            underlyingError:nil
                                                description:@"Unable to open the browser."];
    [session failExternalUserAgentFlowWithError:safariError];
  }*/
  return true;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion {
  if (!_externalUserAgentFlowInProgress) {
    // Ignore this call if there is no authorization flow in progress.
    if (completion) completion();
    return;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  ASWebAuthenticationSession *webAuthenticationSession = _webAuthenticationSession;
#pragma clang diagnostic pop

  // Ideally the browser tab with the URL should be closed here, but the AppAuth library does not
  // control the browser.
  [self cleanUp];
  if (webAuthenticationSession) {
    // dismiss the ASWebAuthenticationSession
    [webAuthenticationSession cancel];
    if (completion) completion();
  } else if (completion) {
    completion();
  }
}

- (void)cleanUp {
  _session = nil;
  _externalUserAgentFlowInProgress = NO;
  _webAuthenticationSession = nil;
}

#pragma mark - ASWebAuthenticationPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
  return _presentingWindow;
}

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX
