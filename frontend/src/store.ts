import { Exome } from "exome"

// We'll have a store called "CounterStore"
class CounterStore extends Exome {
  // Lets set up one property "count" with default value "0"
  public count = 0

  // Now lets create action that will update "count" value
  public increment() {
    this.count += 1
  }
}

export const counter = new CounterStore();
