//
//  NicoUtilityHttpClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// request header
private let kUserAgent = kCommonUserAgent
private let kCookieDomain = "nicovideo.jp"
private let kCookieExpire = TimeInterval(7200)
private let kCookiePath = "/"

// Internal Http Utility
extension NicoUtility {
    func cookiedAsyncRequest(_ httpMethod: String, url: URL, parameters: [String: Any]?, completion: (URLResponse?, Data?, Error?) -> Void) {
        cookiedAsyncRequest(httpMethod, url: url.absoluteString, parameters: parameters, completion: completion)
    }
    
    func cookiedAsyncRequest(_ httpMethod: String, url: String, parameters: [String: Any]?, completion: (URLResponse?, Data?, Error?) -> Void) {
        var parameteredUrl: String = url
        let constructedParameters = constructParameters(parameters)
        
        if httpMethod == "GET" && constructedParameters != nil {
            parameteredUrl += "?" + constructedParameters!
        }
        
        let request = mutableRequestWithCustomHeaders(parameteredUrl)
        request.httpMethod = httpMethod
        
        if httpMethod == "POST" && constructedParameters != nil {
            request.httpBody = constructedParameters!.data(using: String.Encoding.utf8)
        }
        
        if let cookies = sessionCookies() {
            let requestHeader = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = requestHeader
        }
        else {
            logger.error("could not get cookie")
            completion(nil, nil, NSError(domain:"", code:0, userInfo: nil))
        }
        
        let queue = OperationQueue()
        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: queue, completionHandler: completion)
    }
    
    func constructParameters(_ parameters: [String: Any]?) -> String? {
        if parameters == nil {
            return nil
        }
        
        var constructed: NSString = ""
        
        for (key, value) in parameters! {
            if 0 < constructed.length {
                constructed = constructed as String + "&"
            }
            
            constructed = constructed as String + "\(key)=\(value)"
        }
        
        // use custom escape character sets instead of NSCharacterSet.URLQueryAllowedCharacterSet()
        // cause we need to escape strings like this: tpos=1416842780%2E802121&comment%5Flocale=ja%2Djp
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: "?=&")
        
        return constructed.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)
    }
    
    private func mutableRequestWithCustomHeaders(_ url: String) -> NSMutableURLRequest {
        let urlObject = URL(string: url)!
        let mutableRequest = NSMutableURLRequest(url: urlObject)
        
        mutableRequest.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        
        return mutableRequest
    }
    
    private func sessionCookies() -> [HTTPCookie]? {
        // logger.debug("userSessionCookie:[\(userSessionCookie)]")
        if userSessionCookie == nil {
            return nil
        }
        
        var cookies = [HTTPCookie]()
        
        for (name, value) in [("user_session", userSessionCookie!), ("area", "JP"), ("lang", "ja-jp")] {
            if let cookie = HTTPCookie(properties: [
                HTTPCookiePropertyKey.domain: kCookieDomain,
                HTTPCookiePropertyKey.name: name,
                HTTPCookiePropertyKey.value: value,
                HTTPCookiePropertyKey.expires: Date().addingTimeInterval(kCookieExpire),
                HTTPCookiePropertyKey.path: kCookiePath]) {
                cookies.append(cookie)
            }
        }
        
        return cookies
    }
}
