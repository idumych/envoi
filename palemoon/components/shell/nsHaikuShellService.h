/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef nshaikushellservice_h____
#define nshaikushellservice_h____

#include "nsIShellService.h"
#include "mozilla/Attributes.h"

// Default-browser handling on Haiku: Envoi is the default browser when it
// is the preferred application of the web MIME types and URL schemes.
class nsHaikuShellService final : public nsIShellService
{
public:
  nsHaikuShellService() {}

  NS_DECL_ISUPPORTS
  NS_DECL_NSISHELLSERVICE

private:
  ~nsHaikuShellService() {}
};

#endif // nshaikushellservice_h____
