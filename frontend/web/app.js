const getElement = (id) => {
  const element = document.getElementById(id);
  return element || null;
};

const hideElement = (element) => {
  if (!element) {
    return;
  }
  element.setAttribute("hidden", "");
};

const showElement = (element) => {
  if (!element) {
    return;
  }
  element.removeAttribute("hidden");
};

const clearText = (element) => {
  if (!element) {
    return;
  }
  element.textContent = "";
};

const NOTICE_DISMISSED_KEY = "ph_notice_dismissed";
const SETUP_DISMISSED_KEY = "ph_setup_dismissed";
const UPDATE_DISMISSED_KEY = "ph_update_dismissed";

const removeLegacySetupFlags = () => {
  localStorage.removeItem(SETUP_DISMISSED_KEY);
  localStorage.removeItem("ph_setupBanner");
  localStorage.removeItem("ph_setup_banner");
};

const isSupabaseSchemaError = (error) => {
  if (!error) {
    return false;
  }
  const message = typeof error.message === "string" ? error.message : "";
  return error.code === "PGRST106" || message.includes("The schema must be one of the following");
};

const initNotice = () => {
  const noticeEl = getElement("notice");
  const noticeClose = getElement("noticeClose");
  const noticeTextEl = getElement("noticeText");

  if (!noticeEl) {
    return;
  }

  let noticeText = null;
  if (noticeTextEl) {
    const text = noticeTextEl.textContent.trim();
    if (text) {
      noticeText = text;
    }
  } else {
    const text = noticeEl.textContent.trim();
    if (text) {
      noticeText = text;
    }
  }

  const dismissed = sessionStorage.getItem(NOTICE_DISMISSED_KEY) === "1";
  if (!noticeText || dismissed) {
    noticeText = null;
    clearText(noticeTextEl || noticeEl);
    hideElement(noticeEl);
  } else {
    if (noticeTextEl) {
      noticeTextEl.textContent = noticeText;
    }
    showElement(noticeEl);
  }

  if (noticeClose) {
    noticeClose.addEventListener("click", () => {
      sessionStorage.setItem(NOTICE_DISMISSED_KEY, "1");
      noticeText = null;
      clearText(noticeTextEl || noticeEl);
      hideElement(noticeEl);
    });
  }
};

const initSetupBanner = () => {
  const setupBanner = getElement("setupBanner");
  const setupClose = getElement("setupBannerClose");

  if (!setupBanner) {
    return;
  }

  removeLegacySetupFlags();
  hideElement(setupBanner);

  const isDismissed = () => sessionStorage.getItem(SETUP_DISMISSED_KEY) === "1";
  const updateSetupBanner = (error) => {
    if (isDismissed()) {
      hideElement(setupBanner);
      return;
    }
    if (isSupabaseSchemaError(error)) {
      showElement(setupBanner);
    } else {
      hideElement(setupBanner);
    }
  };

  if (setupClose) {
    setupClose.addEventListener("click", () => {
      sessionStorage.setItem(SETUP_DISMISSED_KEY, "1");
      hideElement(setupBanner);
    });
  }

  window.reportSupabaseError = (error) => {
    updateSetupBanner(error);
  };
};

const initUpdateToast = () => {
  const updateToast = getElement("updateToast");
  const updateClose = getElement("updateToastClose");

  if (!updateToast) {
    return;
  }

  const isDismissed = () => sessionStorage.getItem(UPDATE_DISMISSED_KEY) === "1";
  const showUpdateToast = () => {
    if (isDismissed()) {
      hideElement(updateToast);
      return;
    }
    showElement(updateToast);
  };

  const hideUpdateToast = () => {
    hideElement(updateToast);
  };

  hideUpdateToast();

  if (updateClose) {
    updateClose.addEventListener("click", () => {
      sessionStorage.setItem(UPDATE_DISMISSED_KEY, "1");
      hideUpdateToast();
    });
  }

  if (!("serviceWorker" in navigator)) {
    return;
  }

  navigator.serviceWorker
    .getRegistration()
    .then((registration) => {
      if (!registration) {
        return;
      }
      if (registration.waiting) {
        showUpdateToast();
      }
      registration.addEventListener("updatefound", () => {
        const newWorker = registration.installing;
        if (!newWorker) {
          return;
        }
        newWorker.addEventListener("statechange", () => {
          if (newWorker.state === "installed" && navigator.serviceWorker.controller) {
            showUpdateToast();
          }
        });
      });
    })
    .catch(() => {
      hideUpdateToast();
    });
};

document.addEventListener("DOMContentLoaded", () => {
  initNotice();
  initSetupBanner();
  initUpdateToast();
});
