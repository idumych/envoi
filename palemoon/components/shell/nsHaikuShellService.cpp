/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "nsHaikuShellService.h"
#include "nsIFile.h"
#include "nsStringAPI.h"

#include <string.h>

#pragma GCC visibility push(default)
#include <app/Roster.h>
#include <interface/GraphicsDefs.h>
#include <interface/Screen.h>
#include <storage/Entry.h>
#include <storage/MimeType.h>
#pragma GCC visibility pop

// Must match app_signature in palemoon/app/haiku/Envoi.rdef.in.
#define APP_SIGNATURE "application/x-vnd.Envoi"

static const char* const kHttpTypes[] = {
  "application/x-vnd.Be.URL.http",
  "application/x-vnd.Be.URL.https",
};

static const char* const kDocumentTypes[] = {
  "text/html",
  "application/xhtml+xml",
};

NS_IMPL_ISUPPORTS(nsHaikuShellService, nsIShellService)

static bool
IsPreferredApp(const char* aType)
{
  BMimeType mime(aType);
  char preferred[B_MIME_TYPE_LENGTH] = { 0 };
  if (mime.InitCheck() != B_OK || mime.GetPreferredApp(preferred) != B_OK) {
    return false;
  }
  return strcasecmp(preferred, APP_SIGNATURE) == 0;
}

static void
SetPreferredApp(const char* aType)
{
  BMimeType mime(aType);
  if (mime.InitCheck() != B_OK) {
    return;
  }
  if (!mime.IsInstalled()) {
    mime.Install();
  }
  mime.SetPreferredApp(APP_SIGNATURE);
}

NS_IMETHODIMP
nsHaikuShellService::IsDefaultBrowser(bool aStartupCheck, bool aForAllTypes,
                                      bool* aIsDefaultBrowser)
{
  *aIsDefaultBrowser = false;
  for (const char* type : kHttpTypes) {
    if (!IsPreferredApp(type)) {
      return NS_OK;
    }
  }
  if (aForAllTypes) {
    for (const char* type : kDocumentTypes) {
      if (!IsPreferredApp(type)) {
        return NS_OK;
      }
    }
  }
  *aIsDefaultBrowser = true;
  return NS_OK;
}

NS_IMETHODIMP
nsHaikuShellService::SetDefaultBrowser(bool aClaimAllTypes, bool aForAllUsers)
{
  for (const char* type : kHttpTypes) {
    SetPreferredApp(type);
  }
  for (const char* type : kDocumentTypes) {
    SetPreferredApp(type);
  }
  return NS_OK;
}

NS_IMETHODIMP
nsHaikuShellService::SetDesktopBackground(nsIDOMElement* aElement,
                                          int32_t aPosition)
{
  // canSetDesktopBackground is not offered, so the UI never calls this.
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
nsHaikuShellService::OpenApplication(int32_t aApplication)
{
  const char* type = nullptr;
  switch (aApplication) {
    case APPLICATION_MAIL:
      type = "application/x-vnd.Be.URL.mailto";
      break;
    case APPLICATION_NEWS:
      type = "application/x-vnd.Be.URL.news";
      break;
    default:
      return NS_ERROR_NOT_AVAILABLE;
  }
  status_t err = be_roster->Launch(type);
  return (err == B_OK || err == B_ALREADY_RUNNING) ? NS_OK : NS_ERROR_FAILURE;
}

NS_IMETHODIMP
nsHaikuShellService::GetDesktopBackgroundColor(uint32_t* aColor)
{
  BScreen screen;
  if (!screen.IsValid()) {
    return NS_ERROR_FAILURE;
  }
  rgb_color c = screen.DesktopColor();
  *aColor = (uint32_t(c.red) << 16) | (uint32_t(c.green) << 8) | c.blue;
  return NS_OK;
}

NS_IMETHODIMP
nsHaikuShellService::SetDesktopBackgroundColor(uint32_t aColor)
{
  BScreen screen;
  if (!screen.IsValid()) {
    return NS_ERROR_FAILURE;
  }
  rgb_color c;
  c.red = (aColor >> 16) & 0xff;
  c.green = (aColor >> 8) & 0xff;
  c.blue = aColor & 0xff;
  c.alpha = 255;
  screen.SetDesktopColor(c, true);
  return NS_OK;
}

NS_IMETHODIMP
nsHaikuShellService::OpenApplicationWithURI(nsIFile* aApplication,
                                            const nsACString& aURI)
{
  nsAutoCString path;
  nsresult rv = aApplication->GetNativePath(path);
  NS_ENSURE_SUCCESS(rv, rv);

  BEntry entry(path.get(), true);
  entry_ref ref;
  if (entry.GetRef(&ref) != B_OK) {
    return NS_ERROR_FILE_NOT_FOUND;
  }
  nsCString uri(aURI);
  char* argv[] = { const_cast<char*>(uri.get()) };
  status_t err = be_roster->Launch(&ref, 1, argv);
  return (err == B_OK || err == B_ALREADY_RUNNING) ? NS_OK : NS_ERROR_FAILURE;
}

NS_IMETHODIMP
nsHaikuShellService::GetDefaultFeedReader(nsIFile** _retval)
{
  return NS_ERROR_FAILURE;
}
