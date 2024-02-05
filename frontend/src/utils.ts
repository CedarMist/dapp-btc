import { nothing } from 'lit';

export const ifTrue = <T>(cond:boolean, value:T) => cond ? value : nothing;
