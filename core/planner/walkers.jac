"""Planner walkers: per-user graph operations, bridged to every client app."""

import from core.planner.models {
    Task,
    ShoppingItem,
    categorize,
    generate_shopping_list
}

# --- Task Walkers ---

walker:protect AddTask {
    has title: str,
        reports: list[Task] = [];

    can create with Root entry {
        category = str(categorize(self.title)).split(".")[-1].lower();
        new_task = here ++> Task(title=self.title, category=category);
        report new_task;
    }
}

walker:protect ListTasks {
    has results: list[Task] = [],
        reports: list[list[Task]] = [];

    can start with Root entry {
        visit [-->];
    }

    can collect with Task entry {
        self.results.append(here);
    }

    can done with Root exit {
        report self.results;
    }
}

walker:protect ToggleTask {
    has task_id: str,
        reports: list[Task] = [];

    can search with Root entry { visit [-->]; }

    can toggle with Task entry {
        if jid(here) == self.task_id {
            here.done = not here.done;
            report here;
            disengage;
        }
    }
}

walker:protect DeleteTask {
    has task_id: str;

    can search with Root entry { visit [-->]; }

    can remove with Task entry {
        if jid(here) == self.task_id {
            del here;
            report {"deleted": self.task_id};
            disengage;
        }
    }
}

# --- Shopping List Walkers ---

walker:protect GenerateShoppingList {
    has meal_description: str,
        reports: list[list[ShoppingItem]] = [];

    can generate with Root entry {
        visit [-->];
        ingredients = generate_shopping_list(self.meal_description);
        for ing in ingredients {
            here ++> ShoppingItem(
                name=ing.name,
                quantity=ing.quantity,
                unit=str(ing.unit).split(".")[-1].lower(),
                cost=ing.cost,
                carby=ing.carby
            );
        }
        report [here-->][?:ShoppingItem];
    }

    can clear_old with ShoppingItem entry {
        del here;
    }
}

walker:protect GetShoppingList {
    has items: list[ShoppingItem] = [],
        reports: list[list[ShoppingItem]] = [];

    can collect with Root entry { visit [-->]; }

    can gather with ShoppingItem entry {
        self.items.append(here);
    }

    can done with Root exit { report self.items; }
}

walker:protect ClearShoppingList {
    can collect with Root entry { visit [-->]; }

    can clear with ShoppingItem entry {
        del here;
        report {"cleared": True};
    }
}
