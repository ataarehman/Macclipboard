document.querySelectorAll(".pill").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".pill").forEach((pill) => pill.classList.remove("is-on"));
    document.querySelectorAll(".pane").forEach((pane) => pane.classList.remove("is-on"));
    button.classList.add("is-on");
    document.getElementById("pane-" + button.dataset.tab)?.classList.add("is-on");
  });
});

const contactForm = document.getElementById("contact-form");
if (contactForm) {
  contactForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const data = new FormData(contactForm);
    const name = String(data.get("name") || "").trim();
    const email = String(data.get("email") || "").trim();
    const message = String(data.get("message") || "").trim();
    const title = encodeURIComponent(name ? `Contact from ${name}` : "MacClipboard contact");
    const body = encodeURIComponent(
      `Name: ${name}\nEmail: ${email}\n\n${message}`
    );
    window.location.href = `https://github.com/ataarehman/Macclipboard/issues/new?title=${title}&body=${body}`;
  });
}

const copyBank = document.getElementById("copy-bank");
if (copyBank) {
  const details = [
    "Amount: $15 USD",
    "Bank name: Citibank",
    "Bank address: 111 Wall Street, New York, NY 10043, USA",
    "Routing (ABA): 031100209",
    "SWIFT code: CITIUS33",
    "Account number: 70580760002386697",
    "Account type: CHECKING",
    "Beneficiary name: Ch Atta ur Rehman",
    "Memo: MacClipboard"
  ].join("\n");

  copyBank.addEventListener("click", async () => {
    const status = document.getElementById("copy-status");
    try {
      await navigator.clipboard.writeText(details);
      if (status) {
        status.hidden = false;
        status.textContent = "Copied. Paste into your bank transfer.";
      }
    } catch {
      if (status) {
        status.hidden = false;
        status.textContent = "Copy failed. Select the details above instead.";
      }
    }
  });
}
