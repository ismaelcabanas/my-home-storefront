import { Service } from "diod";

import { Clock } from "../domain/Clock";

@Service()
export class SystemClock implements Clock {
	now(): Date {
		return new Date();
	}
}
