z <- stats::qnorm(0.975)
event <- read_tab("event.csv") |>
  dplyr::mutate(
    lower = estimate - z * std_error, upper = estimate + z * std_error, birthday = shift == 0L,
    state = factor(state_labels[scope], levels = state_labels)
  )

event_plot <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(shift, estimate, colour = birthday)) +
    ggplot2::geom_hline(yintercept = 0, colour = reference_colour, linewidth = 0.3) +
    ggplot2::geom_vline(xintercept = -7.5, colour = reference_colour, linewidth = 0.2, linetype = "dotted") +
    ggplot2::geom_pointrange(ggplot2::aes(ymin = lower, ymax = upper), size = 0.12, linewidth = 0.3) +
    ggplot2::scale_colour_manual(values = c(`FALSE` = estimate_colour, `TRUE` = birthday_colour), guide = "none") +
    ggplot2::scale_x_continuous(breaks = seq(-30, 30, 10)) +
    ggplot2::scale_y_continuous(labels = \(x) format(100 * x, trim = TRUE, drop0trailing = TRUE)) +
    ggplot2::labs(
      x = "Days from Election Day to birthday (negative: birthday before Election Day)",
      y = "Difference in share voting (percentage points)"
    ) +
    theme_paper()
}

turnout <- dplyr::filter(event, outcome == "voted")
save_evidence(event_plot(turnout) + ggplot2::facet_wrap(~state, ncol = 2), "turnout")

methods <- event |>
  dplyr::filter(outcome != "voted", scope != "Pooled") |>
  dplyr::mutate(panel = paste0(state, ": ", c(polls = "at the polls", early = "early", mail = "by mail")[outcome])) |>
  dplyr::mutate(panel = factor(panel, unique(panel[order(state, match(outcome, names(outcomes)))])))
save_evidence(event_plot(methods) + ggplot2::facet_wrap(~panel, ncol = 3, scales = "free_y"), "methods")
