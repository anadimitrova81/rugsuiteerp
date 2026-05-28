// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

Turbo.setConfirmMethod((message, formElement, submitter) => {
  const method = (
    submitter?.dataset?.turboMethod ||
    formElement?.querySelector('input[name="_method"]')?.value ||
    formElement?.method ||
    ""
  ).toLowerCase()
  const isDestructive = method === "delete"

  const fieldList = (submitter?.dataset?.confirmFields || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
  const showItems = fieldList.includes("items")
  const showWeight = fieldList.includes("weight")
  const isCollecting = showItems || showWeight

  const confirmLabel = isDestructive ? "Изтрий" : "Потвърди"
  const confirmClass = isDestructive ? "btn-danger" : "btn-primary"
  const title = isDestructive
    ? "Потвърдете изтриването"
    : showItems && showWeight
      ? "Теглене на килимите"
      : showItems
        ? "Брой артикули"
        : showWeight
          ? "Тегло на килимите"
          : "Промяна на статус"

  let inputs = ""
  if (showItems) {
    inputs += `
      <label class="confirm-dialog-field">
        <span>Брой артикули</span>
        <input type="number" name="dialog_items" min="1" step="1" required>
      </label>
    `
  }
  if (showWeight) {
    inputs += `
      <label class="confirm-dialog-field">
        <span>Общо тегло (кг)</span>
        <input type="number" name="dialog_weight" min="0.1" step="0.1" required>
      </label>
    `
  }
  const fieldsClass = showItems && showWeight ? "confirm-dialog-fields" : "confirm-dialog-fields confirm-dialog-fields-single"
  const extraFields = isCollecting ? `<div class="${fieldsClass}">${inputs}</div>` : ""

  const dialog = document.createElement("dialog")
  dialog.classList.add("confirm-dialog")
  dialog.innerHTML = `
    <header class="confirm-dialog-header">
      <h3 class="confirm-dialog-title">${title}</h3>
    </header>
    <div class="confirm-dialog-content">
      ${message ? `<p>${message}</p>` : ""}
      ${extraFields}
      <div class="confirm-dialog-actions">
        <button class="btn btn-secondary" value="cancel" type="button">Отказ</button>
        <button class="btn ${confirmClass}" value="confirm" type="button">${confirmLabel}</button>
      </div>
    </div>
  `
  document.body.appendChild(dialog)
  dialog.showModal()

  if (isCollecting) {
    const firstInput = dialog.querySelector("input")
    if (firstInput) firstInput.focus()
  }

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => {
      resolve(dialog.returnValue === "confirm")
      dialog.remove()
    })
    dialog.querySelectorAll("button").forEach((button) => {
      button.addEventListener("click", () => {
        if (button.value === "confirm" && isCollecting) {
          if (showItems) {
            const itemsInput = dialog.querySelector('input[name="dialog_items"]')
            if (!itemsInput.reportValidity()) return
          }
          if (showWeight) {
            const weightInput = dialog.querySelector('input[name="dialog_weight"]')
            if (!weightInput.reportValidity()) return
          }
          if (showItems) {
            const itemsInput = dialog.querySelector('input[name="dialog_items"]')
            const formItems = formElement.querySelector('input[name="request[number_of_items]"]')
            if (formItems) formItems.value = itemsInput.value
          }
          if (showWeight) {
            const weightInput = dialog.querySelector('input[name="dialog_weight"]')
            const formWeight = formElement.querySelector('input[name="request[weight]"]')
            if (formWeight) formWeight.value = weightInput.value
          }
        }
        dialog.returnValue = button.value
        dialog.close()
      })
    })
  })
})
